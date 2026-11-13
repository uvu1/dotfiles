"""Offline tests: no real SSH host, tool installation, or active config writes."""

import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import shutil
import struct
import subprocess
import tarfile
import tempfile
import time
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "mise/dotfiles/.config/nvim"
SPEC = importlib.util.spec_from_file_location(
    "remote_worker", CONFIG / "remote-dev/worker.py"
)
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)
NVIM = shutil.which("nvim")


class WorkerTests(unittest.TestCase):
    def test_plan_has_no_side_effects(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / "absent"
            result = json.loads(
                subprocess.check_output(
                    [
                        "python3",
                        "-B",
                        str(CONFIG / "remote-dev/worker.py"),
                        "plan",
                        "--cache",
                        str(cache),
                    ],
                    text=True,
                )
            )
            self.assertFalse(cache.exists())
            self.assertEqual(
                set(result["artifacts"]["platforms"]),
                {"linux-x86_64", "linux-arm64", "macos-x86_64", "macos-arm64"},
            )
            for entries in result["artifacts"]["platforms"].values():
                for artifact in entries.values():
                    self.assertRegex(artifact["sha256"], "^[a-f0-9]{64}$")
                    self.assertTrue(artifact["url"].startswith("https://"))

    def test_platforms_and_option_injection(self):
        self.assertEqual(worker.platform("Darwin", "arm64"), "macos-arm64")
        self.assertEqual(worker.platform("Linux", "aarch64"), "linux-arm64")
        for host in (
            "-oProxyCommand=bad",
            "host;touch /tmp/bad",
            "docker:target",
            "x\ny",
        ):
            with self.assertRaises(ValueError):
                worker.host_name(host)
        with self.assertRaises(ValueError):
            worker.platform("Linux", "riscv64")

    def test_probe_quotes_paths_and_rejects_musl(self):
        with mock.patch.object(
            worker,
            "ssh",
            side_effect=[
                "Linux\naarch64\n/home/test user\nglibc",
                "/home/test user/a'b",
            ],
        ) as ssh:
            value = worker.probe("example", "~/a'b")
            self.assertEqual(value["project"], "/home/test user/a'b")
            self.assertIn(worker.q("/home/test user/a'b"), ssh.call_args.args[1])
        with mock.patch.object(
            worker, "ssh", return_value="Linux\nx86_64\n/home/test\nmusl"
        ):
            with self.assertRaises(ValueError):
                worker.probe("example", "~")

    def test_archive_traversal_and_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "bad.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("../escape", "bad")
            with self.assertRaises(ValueError):
                worker.unpack(archive, "bad.zip", root / "out")
            archive = root / "bad.tar.gz"
            with tarfile.open(archive, "w:gz") as t:
                item = tarfile.TarInfo("escape")
                item.type = tarfile.SYMTYPE
                item.linkname = "../../outside"
                t.addfile(item)
            with self.assertRaises(tarfile.TarError):
                worker.unpack(archive, "bad.tar.gz", root / "out2")
            self.assertFalse((root / "escape").exists())

    def test_corrupt_download_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "fixture"
            source.write_bytes(b"correct")
            spec = {"url": source.as_uri(), "sha256": worker.digest(source)}
            cached = worker.download(spec, root / "cache")
            cached.write_bytes(b"corrupt")
            self.assertEqual(
                worker.download(spec, root / "cache").read_bytes(), b"correct"
            )
            source.write_bytes(b"wrong")
            with self.assertRaises(ValueError):
                worker.download(dict(spec, sha256="0" * 64), root / "cache")

    def test_wrapper_preserves_arguments_and_private_node(self):
        with tempfile.TemporaryDirectory(prefix="remote tools ") as tmp:
            root = Path(tmp)
            node = root / "node/bin/node"
            node.parent.mkdir(parents=True)
            node.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            node.chmod(0o755)
            worker.wrapper(
                root / "bin", "server", '"$BASE/node/bin/node" "$BASE/entry.js"'
            )
            value = subprocess.check_output(
                [root / "bin/server", "path with spaces", "literal$(text)"], text=True
            ).splitlines()
            self.assertEqual(
                value, [str(root / "entry.js"), "path with spaces", "literal$(text)"]
            )

    def test_clean_config_excludes_state_and_builds(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            source.mkdir()
            (source / "init.lua").write_text("return true")
            for name in (".git", "node_modules", "__pycache__"):
                (source / name).mkdir()
                (source / name / "private").touch()
            worker.clean_config(source, root / "config")
            self.assertEqual(
                [p.name for p in (root / "config").iterdir()], ["init.lua"]
            )

    def test_reconnect_to_older_session_keeps_matching_release_id(self):
        value = {
            "host": "fixture",
            "home": "/home/test",
            "project": "/home/test/project",
            "id": "a" * 24,
            "release": "/home/test/.remote-nvim/releases/" + "a" * 24,
            "version": "v0.12.4",
        }
        live = {
            "release": "/home/test/.remote-nvim/releases/" + "b" * 24,
            "version": "v0.12.3",
            "address": "/home/test/.remote-nvim/run/s123",
            "pid": 123,
        }
        with mock.patch.object(worker, "ssh", return_value=json.dumps(live)) as ssh:
            result = worker.attach(value)
            self.assertEqual(result["id"], "b" * 24)
            self.assertEqual(result["version"], "v0.12.3")
            self.assertEqual(worker.attach(result), result)
            self.assertIn("/nvim/v0.12.3/bin/nvim", ssh.call_args.args[1])


@unittest.skipUnless(NVIM, "Neovim is required")
class NeovimTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="nvim remote test ")
        self.root = Path(self.tmp.name)
        self.env = dict(
            os.environ,
            HOME=str(self.root),
            TERM="xterm-256color",
            NVIM_REMOTE_DEV="1",
            NVIM_REMOTE_CHECK="1",
            XDG_CONFIG_HOME=str(self.root / "config"),
            XDG_DATA_HOME=str(self.root / "data"),
            XDG_STATE_HOME=str(self.root / "state"),
            XDG_CACHE_HOME=str(self.root / "cache"),
        )
        self.processes = []

    def tearDown(self):
        for proc in reversed(self.processes):
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
        self.tmp.cleanup()

    def nvim(self, *args, **kwargs):
        return subprocess.run(
            [NVIM, "-u", "NONE", "-i", "NONE", "--headless", *args],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
            **kwargs,
        )

    def test_remote_profile_skips_mise_and_compilation(self):
        lua = (
            "vim.opt.rtp:prepend("
            + json.dumps(str(CONFIG))
            + '); require("config.options"); assert(not require("lib.mise").available()); assert(require("lib.mise").spawn_env().PATH==vim.env.PATH); assert(dofile('
            + json.dumps(str(CONFIG / "lua/plugins/blink.lua"))
            + ')[1].opts.fuzzy.implementation=="lua"); require("remote_dev").setup(); assert(vim.fn.exists(":RemoteDevConnect")==2); assert(vim.fn.maparg("<Space>mc","n")=="")'
        )
        # mapleader is unset under -u NONE; mappings still register using default.
        result = self.nvim("-c", "lua " + lua, "+qa")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Error", result.stderr)

    def test_session_probe_rejects_stale_or_unrelated_address(self):
        record = self.root / "session.json"
        record.write_text(
            json.dumps(
                {
                    "address": str(self.root / ".remote-nvim/run/stale"),
                    "pid": os.getpid(),
                }
            )
        )
        self.env["NVIM_REMOTE_RECORD"] = str(record)
        result = self.nvim("-l", str(CONFIG / "remote-dev/session.lua"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_authentication_fallback_and_report_open_splits(self):
        ssh = self.root / "ssh"
        ssh.write_text("#!/bin/sh\nexit 1\n")
        ssh.chmod(0o755)
        self.env.update(NVIM_REMOTE_DEV="0", NVIM_REMOTE_SSH_BIN=str(ssh))
        script = self.root / "authentication.lua"
        script.write_text(
            "vim.opt.rtp:prepend("
            + json.dumps(str(CONFIG))
            + ")\n"
            + """
local ok, err = pcall(function()
  local failed = false
  vim.notify = function(message)
    if message == 'SSH認証が完了しませんでした' then failed = true end
  end
  vim.ui.input = function(_, callback) callback('~/project') end
  local remote = require('remote_dev')
  remote.setup()
  vim.cmd.RemoteDevConnect('fixture')
  assert(vim.wait(5000, function() return failed end, 10), 'authentication terminal did not open')
  assert(#vim.api.nvim_list_wins() == 2)
  assert(vim.bo.buftype == 'terminal')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  remote.health()
  assert(#vim.api.nvim_list_wins() == 3)
  assert(vim.api.nvim_buf_get_name(0) == 'remote-dev://health')
  assert(vim.bo.buftype == 'nofile')
end)
if not ok then io.stderr:write(tostring(err)); vim.cmd.cquit() end
vim.cmd('qa!')
"""
        )
        result = self.nvim("-l", str(script))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("E476", result.stderr)

    def test_deploy_is_atomic_and_idempotent(self):
        for failure in (None, "checksum", "startup", "missing-tool", "broken-tool"):
            with (
                self.subTest(failure=failure),
                tempfile.TemporaryDirectory(prefix="remote home ") as tmp,
            ):
                home = Path(tmp)
                base = home / ".remote-nvim"
                old = base / "releases/old"
                old.mkdir(parents=True)
                (old / "unsaved-session").write_text("keep")
                (base / "current").symlink_to(old)
                stage = home / "local-stage"
                config = stage / "config"
                config.mkdir(parents=True)
                (config / "init.lua").write_text(
                    'error("broken configuration")'
                    if failure == "startup"
                    else "vim.g.remote_dev_smoke=true"
                )
                portable = stage / "data/nvim/portable/bin"
                portable.mkdir(parents=True)
                tool = portable / "basedpyright-langserver"
                tool.write_text("#!/bin/sh\nexit 0\n")
                tool.chmod(0o644 if failure == "missing-tool" else 0o755)
                (stage / "checksums").write_text(
                    ("0" * 64 if failure == "checksum" else worker.digest(tool))
                    + "  data/nvim/portable/bin/basedpyright-langserver\n"
                )
                value = {
                    "host": "fixture",
                    "home": str(home),
                    "id": "a" * 24,
                    "release": str(base / "releases" / ("a" * 24)),
                    "stage": str(stage),
                    "platform": "linux-x86_64",
                    "version": worker.MANIFEST["nvim_version"],
                    "plugin": "fixture",
                }
                release = Path(value["release"])
                calls = []

                def provision(argv, **kwargs):
                    calls.append(argv)
                    shutil.copytree(config, release / "config/nvim")
                    shutil.copytree(stage / "data", release / "data")
                    binaries = release / "nvim" / value["version"] / "bin"
                    binaries.mkdir(parents=True)
                    (binaries / "nvim").symlink_to(NVIM)
                    (release / "bin").mkdir()
                    (release / "bin/rg").symlink_to(shutil.which("rg"))
                    for name in (
                        "bin/fd",
                        "bin/biome",
                        "bin/ruff",
                        "data/nvim/portable/node/bin/node",
                        "data/nvim/portable/bin/stylua",
                        "data/nvim/portable/bin/lua-language-server",
                        "data/nvim/portable/bin/clangd",
                        "data/nvim/portable/bin/rust-analyzer",
                        "data/nvim/portable/bin/gopls",
                    ):
                        binary = release / name
                        binary.parent.mkdir(parents=True, exist_ok=True)
                        binary.write_text(
                            "#!/bin/sh\nexit "
                            + (
                                "1"
                                if failure == "broken-tool" and name.endswith("node")
                                else "0"
                            )
                            + "\n"
                        )
                        binary.chmod(0o755)
                    launcher = release / "rnvim"
                    launcher.write_text(
                        "#!/bin/sh\nexport XDG_CONFIG_HOME="
                        + worker.q(str(release / "config"))
                        + "\nexec "
                        + worker.q(NVIM)
                        + ' "$@"\n'
                    )
                    launcher.chmod(0o755)

                def local_ssh(host, script, **kwargs):
                    result = subprocess.run(
                        ["sh", "-c", "set -eu\n" + script],
                        env=dict(self.env, HOME=str(home)),
                        check=True,
                        capture_output=True,
                        text=True,
                        timeout=15,
                        **kwargs,
                    )
                    return result.stdout.strip()

                with (
                    mock.patch.object(worker, "run", side_effect=provision),
                    mock.patch.object(worker, "ssh", side_effect=local_ssh),
                    mock.patch.dict(
                        os.environ,
                        {
                            "NVIM_REMOTE_SSH_BIN": "/fake/ssh",
                            "NVIM_REMOTE_LOCAL_NVIM": NVIM,
                        },
                    ),
                ):
                    if failure:
                        with self.assertRaises(subprocess.CalledProcessError):
                            worker.deploy(value, home / "cache")
                        self.assertEqual((base / "current").resolve(), old)
                    else:
                        worker.deploy(value, home / "cache")
                        self.assertEqual((base / "current").resolve(), release)
                        # Re-selecting a cached release must still activate it.
                        (base / "current").replace(base / "previous")
                        (base / "current").symlink_to(old)
                        worker.deploy(value, home / "cache")
                        self.assertEqual(len(calls), 1)
                        self.assertEqual((base / "current").resolve(), release)
                self.assertEqual((old / "unsaved-session").read_text(), "keep")

    def test_ui_roundtrip_retains_unsaved_remote_buffer(self):
        import fcntl
        import termios

        self.env["NVIM_REMOTE_RECORD"] = str(self.root / "session.json")
        address = str(self.root / "local.sock")
        bootstrap = (
            "lua vim.opt.rtp:prepend("
            + json.dumps(str(CONFIG))
            + '); vim.g.mapleader=" "; require("remote_dev").setup()'
        )
        local = subprocess.Popen(
            [NVIM, "-u", "NONE", "-i", "NONE", "--headless", "--listen", address],
            env=self.env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        remote = subprocess.Popen(
            [
                NVIM,
                "-u",
                "NONE",
                "-i",
                "NONE",
                "--headless",
                "--cmd",
                bootstrap,
                "-c",
                'lua require("remote_dev.server").start()',
            ],
            env=self.env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.processes.extend([local, remote])
        deadline = time.monotonic() + 5
        while (
            not Path(address).exists()
            or not Path(self.env["NVIM_REMOTE_RECORD"]).exists()
        ) and time.monotonic() < deadline:
            time.sleep(0.02)
        record = json.loads(Path(self.env["NVIM_REMOTE_RECORD"]).read_text())
        remote_address = record["address"]
        self.assertTrue(Path(remote_address).is_socket())
        self.assertEqual(Path(remote_address).parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(
            Path(self.env["NVIM_REMOTE_RECORD"]).stat().st_mode & 0o777, 0o600
        )

        def expr(addr, value):
            return subprocess.check_output(
                [NVIM, "--server", addr, "--remote-expr", value],
                env=self.env,
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=3,
            ).strip()

        expr(
            remote_address, 'execute("let g:remote_dev_return = ' + repr(address) + '")'
        )
        expr(
            remote_address, 'nvim_buf_set_lines(0,0,-1,v:true,["unsaved remote work"])'
        )
        master, slave = pty.openpty()
        try:
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
            ui = subprocess.Popen(
                [NVIM, "--server", address, "--remote-ui"],
                env=self.env,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                start_new_session=True,
            )
            self.processes.append(ui)

            def until(check):
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if select.select([master], [], [], 0)[0]:
                        os.read(master, 65536)
                    if check():
                        return
                    time.sleep(0.02)
                self.fail("UI attach timeout")

            until(lambda: expr(address, "len(nvim_list_uis())") == "1")
            os.write(master, (":connect " + remote_address + "\r").encode())
            until(lambda: expr(remote_address, "len(nvim_list_uis())") == "1")
            os.write(master, b":RemoteDevDisconnect\r")
            until(lambda: expr(address, "len(nvim_list_uis())") == "1")
            self.assertEqual(expr(remote_address, "getline(1)"), "unsaved remote work")
            self.assertEqual(expr(remote_address, "&modified"), "1")
            self.assertIsNone(remote.poll())
        finally:
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    unittest.main()
