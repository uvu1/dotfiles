"""Offline configuration checks; no SSH, tool installation, or active-state writes."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "mise/dotfiles/.config/nvim"
NVIM = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
LAZY = Path(os.environ.get("NVIM_TEST_LAZY", Path.home() / ".local/share/nvim/lazy"))


@unittest.skipUnless(NVIM, "Neovim is required")
class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="nvim-config-")
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ)
        for key in ("SSH_CONNECTION", "SSH_TTY", "NVIM_APPNAME", "NVIM_REMOTE_DEV", "__MISE_ORIG_PATH"):
            self.env.pop(key, None)
        self.env.update(
            HOME=str(self.root),
            XDG_CONFIG_HOME=str(self.root / "config"),
            XDG_DATA_HOME=str(self.root / "data"),
            XDG_STATE_HOME=str(self.root / "state"),
            XDG_CACHE_HOME=str(self.root / "cache"),
            MISE_GLOBAL_CONFIG_FILE=str(self.root / "mise.toml"),
            MISE_AUTO_INSTALL="0",
            MISE_EXEC_AUTO_INSTALL="0",
        )
        (self.root / "mise.toml").write_text("")

    def tearDown(self):
        self.tmp.cleanup()

    def run_lua(self, script, *, environment=None):
        path = self.root / "check.lua"
        path.write_text(
            "vim.opt.rtp:prepend(" + json.dumps(str(CONFIG)) + ")\n"
            + "local ok, err = xpcall(function()\n" + script
            + "\nend, debug.traceback)\n"
            + "if not ok then io.stderr:write(err); vim.cmd('cquit 1') end\n"
            + "vim.cmd('qa!')\n"
        )
        result = subprocess.run(
            [NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(path)],
            env=self.env | (environment or {}),
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Error", result.stderr)

    def test_local_and_ssh_profiles(self):
        for environment, remote in (
            ({}, False),
            ({"NVIM_APPNAME": "nvim-remote"}, True),
            ({"SSH_CONNECTION": "test connection"}, True),
            ({"SSH_TTY": "/dev/pts/test"}, True),
        ):
            with self.subTest(environment=environment):
                self.run_lua(
                    'local e = require("config.environment"); assert(e.remote == '
                    + str(remote).lower()
                    + '); require("config.options"); '
                    + ('assert(vim.g.clipboard.name == "Remote OSC52")' if remote else ''),
                    environment=environment,
                )

    def test_project_mise_is_available_over_ssh(self):
        self.run_lua(
            'vim.fn.executable = function(name) return name == "mise" and 1 or 0 end; '
            'local m = require("lib.mise"); assert(m.available()); '
            'assert(vim.deep_equal(m.argv({"gopls"}, "/project"), '
            '{"mise", "x", "-C", "/project", "--", "gopls"}))',
            environment={"SSH_CONNECTION": "test connection"},
        )

    def test_missing_compiler_does_not_install_parsers(self):
        self.run_lua(
            'local executable = vim.fn.executable; '
            'vim.fn.executable = function(name) '
            'if name == "cc" or name == "tree-sitter" then return 0 end '
            'return executable(name) end; '
            'package.preload["nvim-treesitter"] = function() error("must not install parsers") end; '
            'dofile(' + json.dumps(str(CONFIG / "lua/plugins/treesitter.lua")) + ')[1].config()',
        )

    @unittest.skipUnless((LAZY / "blink.cmp").is_dir(), "installed blink.cmp is required")
    def test_completion_without_cargo_or_native_library(self):
        self.run_lua(
            'vim.opt.rtp:append(' + json.dumps(str(LAZY / "blink.lib")) + '); '
            'vim.opt.rtp:append(' + json.dumps(str(LAZY / "blink.cmp")) + '); '
            'local executable = vim.fn.executable; '
            'vim.fn.executable = function(name) if name == "cargo" then return 0 end return executable(name) end; '
            'local spec = dofile(' + json.dumps(str(CONFIG / "lua/plugins/blink.lua")) + ')[1]; '
            'spec.build(); local cmp = require("blink.cmp"); '
            'cmp.library_available = function() return false end; cmp.setup(spec.opts); '
            'assert(cmp.is_enabled())',
        )

    def test_node_server_uses_editor_node_with_project_mise(self):
        self.run_lua(
            'vim.fn.executable = function() return 1 end; '
            'vim.system = function(argv) return {wait = function() '
            'return {code=0, stdout="/editor/bin/" .. argv[#argv]} end} end; '
            'local captured; vim.lsp.rpc.start = function(argv, _, options) captured=argv; return {} end; '
            'require("lib.mise").lsp_cmd({"basedpyright-langserver", "--stdio"}, {node=true})({}, '
            '{root_dir=' + json.dumps(str(self.root)) + '}); '
            'assert(vim.deep_equal(captured, {"mise", "x", "-C", '
            + json.dumps(str(self.root))
            + ', "node@path:/editor", "--", "/editor/bin/basedpyright-langserver", "--stdio"}))',
            environment={"NVIM_APPNAME": "nvim-remote"},
        )

    @unittest.skipUnless(shutil.which("mise") and shutil.which("node"), "mise and Node are required")
    def test_project_shell_wrapper_uses_pinned_node(self):
        old_node = self.root / "old-node/bin/node"
        old_node.parent.mkdir(parents=True)
        old_node.write_text("#!/bin/sh\nprintf WRONG_PROJECT_NODE\\n\n")
        old_node.chmod(0o755)
        (self.root / "mise.toml").write_text(
            '[tools]\nnode = "path:' + str(old_node.parent.parent) + '"\n'
        )
        wrapper = self.root / "node_modules/.bin/typescript-language-server"
        wrapper.parent.mkdir(parents=True)
        wrapper.write_text("#!/bin/sh\nexec node -p process.version\n")
        wrapper.chmod(0o755)
        node = shutil.which("node")
        version = subprocess.check_output([node, "-p", "process.version"], text=True).strip()
        self.run_lua(
            'require("config.environment").tool = function(name) '
            'if name == "node" then return ' + json.dumps(node) + ' end end; '
            'vim.lsp.rpc.start = function(argv, _, opts) '
            'local result = vim.system(argv, {cwd=opts.cwd, env=opts.env, text=true}):wait(10000); '
            'assert(result.code == 0, result.stderr); '
            'assert(vim.trim(result.stdout) == ' + json.dumps(version) + ', result.stdout); return {} end; '
            'require("lib.mise").lsp_cmd({"typescript-language-server", "--stdio"}, '
            '{node=true, local_bin="node_modules/.bin"})({}, {root_dir=' + json.dumps(str(self.root)) + '})',
            environment={"NVIM_APPNAME": "nvim-remote", "MISE_TRUSTED_CONFIG_PATHS": str(self.root), "MISE_OFFLINE": "1"},
        )

    def test_directory_selection_navigates_and_updates_explorer(self):
        folder = self.root / "work space" / "nested"
        folder.mkdir(parents=True)
        (self.root / "not-a-directory").write_text("test")
        (self.root / "shortcut").symlink_to(folder, target_is_directory=True)
        (self.root / "broken").symlink_to(self.root / "missing")
        self.run_lua(
            'vim.api.nvim_set_current_dir(' + json.dumps(str(self.root)) + '); '
            'local current; local refreshed=false; local focused=false; '
            'package.loaded["snacks"]={picker={get=function() return {{ '
            'set_cwd=function(_, dir) current=dir end, '
            'find=function() refreshed=true end, focus=function() focused=true end}} end}}; '
            'local choices={"work space/", "nested/", "このフォルダを使う"}; '
            'vim.ui.select=function(items, opts, callback) '
            'local choice=table.remove(choices,1); local selected; '
            'for _, item in ipairs(items) do '
            'assert(item.label ~= "not-a-directory/" and item.label ~= "broken/"); '
            'if item.label == choice then selected=item end end; '
            'assert(selected, choice); callback(selected) end; '
            'require("lib.explorer").choose_directory(); '
            'assert(vim.fn.getcwd() == ' + json.dumps(str(folder)) + '); '
            'assert(current == vim.fn.getcwd() and refreshed and focused); assert(#choices == 0)',
        )

    def test_cancel_directory_selection_preserves_cwd(self):
        self.run_lua(
            'local before=vim.fn.getcwd(); local calls=0; '
            'vim.ui.select=function(items, opts, callback) calls=calls+1; callback(nil) end; '
            'package.loaded["snacks"]={picker={get=function() error("must preserve windows on cancel") end}}; '
            'require("lib.explorer").choose_directory(); '
            'assert(vim.fn.getcwd()==before and calls==1)',
        )

    def test_directory_prompt_only_on_new_native_ssh_session(self):
        for appname in ("nvim", "nvim-remote"):
            with self.subTest(appname=appname):
                expected = "true" if appname == "nvim-remote" else "false"
                self.run_lua(
                    'local picked, opened=0,0; '
                    'package.loaded["lib.explorer"]={ '
                    'choose_directory=function() picked=picked+1 end, '
                    'focus_or_open=function() opened=opened+1 end}; '
                    'require("config.autocmds"); '
                    'vim.api.nvim_exec_autocmds("VimEnter", {modeline=false}); vim.wait(20); '
                    'assert((picked==1) == ' + expected + '); '
                    'assert(picked+opened==1); '
                    'vim.api.nvim_exec_autocmds("UIEnter", {modeline=false}); vim.wait(20); '
                    'assert(picked+opened==1)',
                    environment={"NVIM_APPNAME": appname},
                )

    @unittest.skipUnless((LAZY / "lazy.nvim").is_dir(), "installed plugins are required")
    def test_full_startup_and_early_completion_capabilities(self):
        for appname in ("nvim", "nvim-remote"):
            with self.subTest(appname=appname):
                config = self.root / "config" / appname
                config.parent.mkdir(exist_ok=True)
                config.symlink_to(CONFIG)
                data = self.root / "data" / appname
                data.mkdir(parents=True)
                (data / "lazy").symlink_to(LAZY)
                source = self.root / (appname + ".lua")
                source.write_text("local value = 1\nprint(value)\n")
                self.run_lua(
                    'vim.go.loadplugins=true; local errors = {}; vim.notify = function(msg, level) '
                    'if level == vim.log.levels.ERROR then errors[#errors+1]=tostring(msg) end end; '
                    'vim.opt.rtp:prepend(' + json.dumps(str(LAZY / "lazy.nvim")) + '); '
                    'local lazy = require("lazy"); local setup = lazy.setup; lazy.setup = function(opts) '
                    'opts.install.missing=false; opts.readme={enabled=false}; return setup(opts) end; '
                    'local executable = vim.fn.executable; vim.fn.executable = function(name) '
                    'if name == "cc" or name == "tree-sitter" then return 0 end return executable(name) end; '
                    'local environment = require("config.environment"); if environment.remote then '
                    'environment.tool = function(name) return "/editor/bin/" .. name end end; '
                    'dofile(' + json.dumps(str(CONFIG / "init.lua")) + '); vim.wait(500); '
                    'if vim.fn.executable("lua-language-server") == 1 then '
                    'vim.cmd.edit(' + json.dumps(str(source)) + '); '
                    'assert(vim.wait(10000, function() '
                    'for _, c in ipairs(vim.lsp.get_clients({bufnr=0})) do '
                    'if c.name == "lua_ls" and c.initialized then return true end end return false end), '
                    '"lua_ls did not initialize"); vim.wait(300); end; '
                    'assert(#errors == 0, table.concat(errors, "\\n")); '
                    'assert(vim.lsp.config["*"].capabilities.textDocument.completion.completionItem.snippetSupport); '
                    'assert(vim.fn.exists(":RemoteDevConnect") == 0); '
                    'assert(vim.fn.exists(":RemoteSSHFSConnect") == 0); '
                    'assert(vim.fn.maparg("<Space>mc", "n") == ":connect ssh://"); '
                    'if environment.remote then '
                    'local start = vim.lsp.rpc.start; local captured; '
                    'vim.lsp.rpc.start=function(argv) captured=argv; return {} end; '
                    'for _, name in ipairs({"cssls", "eslint", "html", "jsonls", "tailwindcss", "ts_ls", "yamlls"}) do '
                    'vim.lsp.config[name].cmd({}, {root_dir=' + json.dumps(str(self.root)) + '}); '
                    'assert(captured[1] == "mise" and captured[5] == "node@path:/editor", name); end; '
                    'vim.lsp.rpc.start=start; '
                    'assert(vim.lsp.config.ts_ls.init_options.tsserver.path == nil); '
                    'assert(vim.lsp.config.ts_ls.init_options.tsserver.fallbackPath == "/editor/lib/tsserver.js"); end',
                    environment={"NVIM_APPNAME": appname},
                )


if __name__ == "__main__":
    unittest.main()
