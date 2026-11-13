"""Build portable editor payloads locally; use remote.nvim to provision them.

Only deploy/attach write to the SSH host. plan never contacts it; prepare probes
it read-only and writes exclusively to the local editor cache. No remote Python,
npm, Go compiler, Nix or mise is needed.
"""

import argparse
import contextlib
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

HERE = Path(__file__).resolve().parent
MANIFEST = json.loads((HERE / "artifacts.json").read_text())
SINGLE = {"rg", "fd", "ruff", "biome"}
GO_TOOLS = {
    "gopls": "golang.org/x/tools/gopls",
    "goimports": "golang.org/x/tools/cmd/goimports",
    "gofumpt": "mvdan.cc/gofumpt",
}
SSH_OPTIONS = [
    "-o",
    "ControlMaster=auto",
    "-o",
    "ControlPath=/tmp/rnvim-%C",
    "-o",
    "ControlPersist=60",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "BatchMode=yes",
]
q = shlex.quote


def run(argv, **kwargs):
    return subprocess.run(
        [str(a) for a in argv], check=True, text=True, stdout=subprocess.PIPE, **kwargs
    ).stdout.strip()


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def dump(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def host_name(value):
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.@:+-]*", value) or value.startswith(
        "docker:"
    ):
        raise ValueError("SSH configのホスト名またはuser@hostを指定してください")
    return value


def ssh(host, script, **kwargs):
    return run(
        [
            os.environ["NVIM_REMOTE_SSH_BIN"],
            *SSH_OPTIONS,
            host_name(host),
            "/bin/sh -c " + q("set -eu\n" + script),
        ],
        **kwargs,
    )


def platform(system, machine):
    system = {"Linux": "linux", "Darwin": "macos"}.get(system)
    machine = {
        "x86_64": "x86_64",
        "amd64": "x86_64",
        "arm64": "arm64",
        "aarch64": "arm64",
    }.get(machine)
    result = f"{system}-{machine}"
    if result not in MANIFEST["platforms"]:
        raise ValueError(f"未対応のOS/CPU: {result}")
    return result


def probe(host, project):
    lines = ssh(
        host,
        'uname -s; uname -m; printf "%s\\n" "$HOME"; if ls /lib/ld-musl-* >/dev/null 2>&1; then echo musl; else echo glibc; fi',
    ).splitlines()
    if len(lines) != 4 or lines[3] == "musl":
        raise ValueError(
            "対象はLinux glibcまたはmacOSです。SSH起動時の余分な出力も確認してください"
        )
    target = platform(*lines[:2])
    home = lines[2]
    if not home.startswith("/") or any(c in home for c in "\n\r"):
        raise ValueError("SSH先のHOMEを解決できません")
    if len((home + "/.remote-nvim/run/s9999999999").encode()) > 103 or any(
        c in home for c in ":%"
    ):
        raise ValueError("SSH先のHOMEはUnix socket転送で使える短いパスにしてください")
    if project == "~":
        project = home
    elif project.startswith("~/"):
        project = home + project[1:]
    if not project.startswith("/") or any(c in project for c in "\n\r"):
        raise ValueError("作業ディレクトリは絶対パスまたは~/で指定してください")
    project = ssh(host, f"cd {q(project)}; pwd -P")
    return {"host": host, "home": home, "platform": target, "project": project}


def download(spec, cache):
    dest = cache / "downloads" / spec["sha256"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_file() and digest(dest) == spec["sha256"]:
        return dest
    print("download " + spec["url"], file=sys.stderr)
    part = dest.with_suffix(".part")
    with (
        urllib.request.urlopen(spec["url"], timeout=120) as source,
        part.open("wb") as output,
    ):
        shutil.copyfileobj(source, output)
    if digest(part) != spec["sha256"]:
        raise ValueError("SHA256不一致: " + spec["url"])
    part.replace(dest)
    return dest


def unpack(archive, url, dest):
    """Reject traversal and escaping symlinks, including zip entries."""
    dest.mkdir(parents=True, exist_ok=True)
    if url.endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                rel = PurePosixPath(info.filename)
                if rel.is_absolute() or ".." in rel.parts or "\\" in info.filename:
                    raise ValueError("不正なアーカイブパス")
                if (info.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError("zipのsymlinkは配布しません")
                output = dest / info.filename
                if info.is_dir():
                    output.mkdir(parents=True, exist_ok=True)
                else:
                    output.parent.mkdir(parents=True, exist_ok=True)
                    with z.open(info) as source, output.open("wb") as target:
                        shutil.copyfileobj(source, target)
                    output.chmod((info.external_attr >> 16) & 0o777 or 0o644)
    else:
        with tarfile.open(archive) as t:
            t.extractall(dest, filter="data")


def executable(path):
    path.chmod(path.stat().st_mode | 0o755)


def wrapper(bindir, name, command):
    path = bindir / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '#!/bin/sh\nBASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)\nexec '
        + command
        + ' "$@"\n'
    )
    executable(path)


def files_hash(root):
    h = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if path.is_file() and "__pycache__" not in path.parts:
            h.update(str(path.relative_to(root)).encode())
            h.update(bytes.fromhex(digest(path)))
    return h.hexdigest()


def clean_config(source, dest):
    # Copy managed editor configuration only, not any machine-local state.
    def ignore(directory, names):
        return [
            name
            for name in names
            if name in {".git", "__pycache__", "node_modules", "tests"}
            or name.endswith((".pyc", ".swp", ".swo"))
        ]

    shutil.copytree(source, dest, ignore=ignore)


def build_plugins(plugins, dest, cache):
    for name, item in sorted(plugins.items()):
        if not re.fullmatch(r"[\w.-]+", name) or not re.fullmatch(
            r"[a-f0-9]{40}", item["commit"]
        ):
            raise ValueError("不正なプラグイン固定情報: " + name)
        match = re.fullmatch(
            r"https://github.com/([\w.-]+/[\w.-]+?)(?:\.git)?", item["url"]
        )
        if not match:
            raise ValueError(
                "配布するプラグインは認証情報を含まないGitHub URLで指定してください: "
                + name
            )
        repo = cache / "git" / name
        if not repo.exists():
            run(["git", "init", "--bare", repo])
        if subprocess.run(
            [
                "git",
                "--git-dir",
                str(repo),
                "cat-file",
                "-e",
                item["commit"] + "^{commit}",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode:
            run(
                [
                    "git",
                    "--git-dir",
                    repo,
                    "fetch",
                    "--depth=1",
                    "https://github.com/" + match[1] + ".git",
                    item["commit"],
                ]
            )
        # git archive excludes .git, build outputs, histories and local changes.
        output = dest / name
        output.mkdir(parents=True)
        with subprocess.Popen(
            ["git", "--git-dir", str(repo), "archive", item["commit"]],
            stdout=subprocess.PIPE,
        ) as proc:
            with tarfile.open(fileobj=proc.stdout, mode="r|") as t:
                t.extractall(output, filter="data")
            if proc.wait():
                raise ValueError("プラグインを展開できません: " + name)


def build_tools(target, payload, cache):
    specs = MANIFEST["platforms"][target]
    bindir = payload / "bin"
    bindir.mkdir(parents=True)
    checks = {}
    for name, spec in specs.items():
        archive = download(spec, cache)
        url = spec["url"]
        if name == "biome":
            checks["bin/biome"] = digest(archive)
            continue
        if url.endswith(".gz") and not url.endswith(".tar.gz"):
            with gzip.open(archive, "rb") as src, (bindir / name).open("wb") as dst:
                shutil.copyfileobj(src, dst)
            executable(bindir / name)
            continue
        extracted = cache / "extracted" / spec["sha256"]
        if not (extracted / ".complete").is_file():
            # Interrupted extraction is isolated from ready releases.
            extracted = Path(str(extracted) + "." + str(os.getpid()))
            unpack(archive, url, extracted)
            (extracted / ".complete").touch()
            extracted.rename(cache / "extracted" / spec["sha256"])
            extracted = cache / "extracted" / spec["sha256"]
        if name == "nvim":
            root = next(extracted.glob("nvim-*"))
            for file in root.rglob("*"):
                if file.is_file():
                    checks[
                        f"nvim/{MANIFEST['nvim_version']}/{file.relative_to(root)}"
                    ] = digest(file)
        elif name in SINGLE:
            checks["bin/" + name] = digest(
                next(p for p in extracted.rglob(name) if p.is_file())
            )
        elif name == "stylua":
            shutil.copy2(next(extracted.rglob(name)), bindir / name)
            executable(bindir / name)
        else:
            binary = "node" if name == "node" else name
            found = next(p for p in extracted.rglob(binary) if p.is_file())
            root = found.parent.parent
            output = payload / name
            if name == "clangd":
                # LLVM ARM64 is a full toolchain archive: retain editor tools,
                # dynamic libraries and clang resource headers, not compilers.
                for path in root.rglob("*"):
                    rel = path.relative_to(root)
                    if path.is_file() and (
                        str(rel) in {"bin/clangd", "bin/clang-format"}
                        or str(rel).startswith("lib/clang/")
                        or re.search(r"\.(so(?:\..*)?|dylib)$", path.name)
                    ):
                        dst = output / rel
                        dst.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(path, dst)
                for tool in ("clangd", "clang-format"):
                    if (output / "bin" / tool).exists():
                        executable(output / "bin" / tool)
                        wrapper(bindir, tool, f'"$BASE/clangd/bin/{tool}"')
            else:
                if name == "node":
                    (output / "bin").mkdir(parents=True)
                    shutil.copy2(found, output / "bin" / binary)
                else:
                    shutil.copytree(
                        root, output, ignore=shutil.ignore_patterns(".complete")
                    )
                executable(output / "bin" / binary)
                if name == "lua-language-server":
                    wrapper(
                        bindir,
                        name,
                        '"$BASE/lua-language-server/bin/lua-language-server"',
                    )
    return checks


def build_languages(target, payload, cache):
    npm = payload / "npm"
    npm.mkdir(exist_ok=True)
    for name in ("package.json", "package-lock.json"):
        shutil.copy2(HERE / name, npm / name)
    os_name, arch = target.split("-")
    env = dict(
        os.environ,
        npm_config_cache=str(cache / "npm"),
        npm_config_os="darwin" if os_name == "macos" else "linux",
        npm_config_cpu="arm64" if arch == "arm64" else "x64",
    )
    run(
        ["npm", "ci", "--ignore-scripts", "--omit=dev", "--no-audit", "--no-fund"],
        cwd=npm,
        env=env,
    )
    # Resolve bin entrypoints instead of copying npm's /usr/bin/env node shebang.
    for package in json.loads((npm / "package.json").read_text())["dependencies"]:
        package_root = npm / "node_modules" / package
        bins = json.loads((package_root / "package.json").read_text()).get("bin", {})
        if isinstance(bins, str):
            bins = {package.split("/")[-1]: bins}
        for name, entry in bins.items():
            relative = (package_root / entry).relative_to(payload)
            wrapper(payload / "bin", name, f'"$BASE/node/bin/node" "$BASE/{relative}"')
    build = payload.parents[2] / "go-build"
    build.mkdir(exist_ok=True)
    for name in ("go.mod", "go.sum"):
        shutil.copy2(HERE / name, build / name)
    env = dict(
        os.environ,
        GOOS="darwin" if os_name == "macos" else "linux",
        GOARCH="arm64" if arch == "arm64" else "amd64",
        CGO_ENABLED="0",
        GOTOOLCHAIN="local",
        GOCACHE=str(cache / "go-build"),
        GOPATH=str(cache / "go"),
    )
    for name, package in GO_TOOLS.items():
        run(
            [
                "go",
                "build",
                "-mod=readonly",
                "-trimpath",
                "-o",
                payload / "bin" / name,
                package,
            ],
            cwd=build,
            env=env,
        )


def prepare(request, cache):
    target = probe(request["host"], request["project"])
    if request["version"] != MANIFEST["nvim_version"]:
        raise ValueError(
            "手元のNeovimとartifacts.jsonの版が異なります。公式成果物とSHA256を更新してください"
        )
    source = Path(request["config"])
    key = hashlib.sha256(
        json.dumps(
            {
                "config": files_hash(source),
                "plugins": request["plugins"],
                "platform": target["platform"],
                "version": request["version"],
            },
            sort_keys=True,
        ).encode()
    ).hexdigest()[:24]
    stage = cache / "stages" / key
    target.update(
        id=key,
        release=target["home"] + "/.remote-nvim/releases/" + key,
        stage=str(stage),
    )
    if not (stage / "ready.json").is_file():
        work = cache / "stages" / (key + "." + str(os.getpid()))
        work.mkdir(parents=True)
        clean_config(source, work / "config")
        data = work / "data" / "nvim"
        build_plugins(request["plugins"], data / "lazy", cache)
        checks = build_tools(target["platform"], data / "portable", cache)
        build_languages(target["platform"], data / "portable", cache)
        for root, remote in ((work / "config", "config/nvim"), (data, "data/nvim")):
            for file in root.rglob("*"):
                if file.is_file():
                    relative = str(file.relative_to(root))
                    if any(c in relative for c in "\n\r\\"):
                        raise ValueError("チェックサムに使用できないファイル名")
                    checks[remote + "/" + relative] = digest(file)
        (work / "checksums").write_text(
            "".join(f"{value}  {name}\n" for name, value in sorted(checks.items()))
        )
        dump(work / "ready.json", {"id": key})
        work.rename(stage)
    target["plugin"] = request["plugin"]
    target["version"] = request["version"]
    return target


def validate_release(value):
    if not re.fullmatch(r"[a-f0-9]{24}", value["id"]):
        raise ValueError("不正なrelease ID")
    if value["release"] != value["home"] + "/.remote-nvim/releases/" + value["id"]:
        raise ValueError("配置先はHOME内の専用releaseに限ります")
    return value["release"]


def activate(value):
    release = validate_release(value)
    # A ready release can be selected again without rewriting its files.
    script = """
local ok, err = pcall(function()
  local p = vim.env.NVIM_REMOTE_RELEASE
  local root = vim.fn.fnamemodify(p, ':h:h')
  local temp = root .. '/current.' .. vim.fn.getpid()
  assert(vim.fn.writefile({'ready'}, p .. '/.ready') == 0)
  assert(vim.uv.fs_symlink(p, temp))
  assert(vim.uv.fs_rename(temp, root .. '/current'))
end)
if not ok then
  io.stderr:write(tostring(err))
  vim.cmd.cquit()
end
"""
    ssh(
        value["host"],
        f"NVIM_REMOTE_RELEASE={q(release)} {q(release + '/nvim/' + value['version'] + '/bin/nvim')} --headless -u NONE -i NONE -c {q('lua ' + script)} +qa",
    )


def deploy(value, cache):
    release = validate_release(value)
    if (
        ssh(value["host"], f"test -f {q(release + '/.ready')} && printf ready || true")
        == "ready"
    ):
        activate(value)
        return value
    stage = Path(value["stage"])
    request = dict(
        value,
        config=str(stage / "config"),
        tools={
            name: MANIFEST["platforms"][value["platform"]][name]
            for name in sorted(SINGLE)
        },
    )
    # The worker's XDG root contains only clean, target-specific payloads.
    spec = cache / "requests" / (value["id"] + ".json")
    dump(spec, request)
    env = dict(
        os.environ,
        XDG_DATA_HOME=str(stage / "data"),
        PATH=str(Path(os.environ["NVIM_REMOTE_SSH_BIN"]).parent)
        + os.pathsep
        + os.environ["PATH"],
    )
    run(
        [
            os.environ["NVIM_REMOTE_LOCAL_NVIM"],
            "-u",
            "NONE",
            "-i",
            "NONE",
            "-l",
            HERE / "provision.lua",
            spec,
        ],
        env=env,
    )
    # Validate bytes before running any downloaded executable.
    ssh(
        value["host"],
        f"cd {q(release)}; cat > .checksums; if command -v sha256sum >/dev/null 2>&1; then sha256sum -c .checksums >/dev/null; else shasum -a 256 -c .checksums >/dev/null; fi",
        input=(stage / "checksums").read_text(),
    )
    launcher = (
        "#!/bin/sh\numask 077\nexport NVIM_REMOTE_DEV=1\nexport NVIM_REMOTE_RELEASE="
        + q(release)
        + "\nexport XDG_RUNTIME_DIR="
        + q(value["home"] + "/.remote-nvim/run")
        + '\nmkdir -p "$XDG_RUNTIME_DIR"\nexport PATH='
        + q(release + "/data/nvim/portable/bin:" + release + "/bin")
        + ':"$PATH"\nexec '
        + q(release + "/rnvim")
        + ' "$@"\n'
    )
    ssh(
        value["host"],
        f"cat > {q(release + '/dev-nvim')}; chmod 755 {q(release + '/dev-nvim')}",
        input=launcher,
    )
    capture = """lua
vim.g.remote_dev_errors = {}
local notify = vim.notify
vim.notify = function(msg, level, opts)
  if (level or 0) >= vim.log.levels.ERROR then
    local errors = vim.g.remote_dev_errors
    errors[#errors + 1] = msg
    vim.g.remote_dev_errors = errors
  end
  notify(msg, level, opts)
end
"""
    smoke = """lua
local p = vim.env.NVIM_REMOTE_RELEASE
if vim.v.errmsg ~= '' or #vim.g.remote_dev_errors > 0
  or vim.fn.executable(p .. '/bin/rg') ~= 1
  or vim.fn.executable(p .. '/data/nvim/portable/bin/basedpyright-langserver') ~= 1 then
  vim.cmd.cquit()
end
local tools = p .. '/data/nvim/portable/'
for _, argv in ipairs({
  {p .. '/bin/rg', '--version'},
  {p .. '/bin/fd', '--version'},
  {p .. '/bin/biome', '--version'},
  {p .. '/bin/ruff', '--version'},
  {tools .. 'node/bin/node', '--version'},
  {tools .. 'bin/stylua', '--version'},
  {tools .. 'bin/lua-language-server', '--version'},
  {tools .. 'bin/clangd', '--version'},
  {tools .. 'bin/rust-analyzer', '--version'},
  {tools .. 'bin/gopls', 'version'},
}) do
  local ok, result = pcall(function() return vim.system(argv, {text=true}):wait(10000) end)
  if not ok or result.code ~= 0 then
    io.stderr:write('起動失敗: ' .. argv[1] .. '\\n' .. tostring(ok and result.stderr or result))
    vim.cmd.cquit()
  end
end
"""
    ssh(
        value["host"],
        f"NVIM_REMOTE_CHECK=1 {q(release + '/dev-nvim')} --headless -i NONE --cmd {q(capture)} -c {q(smoke)} +qa",
    )
    # UV rename replaces the symlink atomically on both Linux and macOS.
    activate(value)
    return value


def attach(value):
    release = validate_release(value)
    session = hashlib.sha256(value["project"].encode()).hexdigest()[:24]
    record = value["home"] + "/.remote-nvim/sessions/" + session + ".json"
    query = f"NVIM_REMOTE_RECORD={q(record)} {q(release + '/nvim/' + value['version'] + '/bin/nvim')} -u NONE -i NONE -l {q(release + '/config/nvim/remote-dev/session.lua')}"

    def session_value(result):
        live = dict(value, **json.loads(result))
        live["id"] = PurePosixPath(live["release"]).name
        live["record"] = record
        validate_release(live)
        return live

    existing = ssh(value["host"], query, timeout=15)
    if existing:
        return session_value(existing)
    env = "NVIM_REMOTE_RECORD=" + q(record)
    ssh(
        value["host"],
        f"mkdir -p {q(str(PurePosixPath(record).parent))}; cd {q(value['project'])}; nohup env {env} {q(release + '/dev-nvim')} --headless -c {q('lua require("remote_dev.server").start()')} >{q(record + '.log')} 2>&1 </dev/null &",
    )
    import time

    for _ in range(100):
        result = ssh(value["host"], query, timeout=15)
        if result:
            return session_value(result)
        time.sleep(0.1)
    raise ValueError("サーバー起動がタイムアウトしました: " + record + ".log")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["plan", "prepare", "deploy", "attach"])
    parser.add_argument("--request")
    parser.add_argument(
        "--cache",
        default=str(
            Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
            / "nvim"
            / "remote-dev"
        ),
    )
    args = parser.parse_args()
    cache = Path(args.cache).resolve()
    if args.action == "plan":
        print(
            json.dumps(
                {
                    "artifacts": MANIFEST,
                    "npm": json.loads((HERE / "package.json").read_text())[
                        "dependencies"
                    ],
                    "go": GO_TOOLS,
                }
            )
        )
        return
    request = json.loads(Path(args.request).read_text())
    with contextlib.redirect_stdout(sys.stderr):
        value = {
            "prepare": lambda: prepare(request, cache),
            "deploy": lambda: deploy(request, cache),
            "attach": lambda: attach(request),
        }[args.action]()
    print(json.dumps(value))


if __name__ == "__main__":
    try:
        main()
    except (
        ValueError,
        OSError,
        subprocess.SubprocessError,
        tarfile.TarError,
        zipfile.BadZipFile,
    ) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
