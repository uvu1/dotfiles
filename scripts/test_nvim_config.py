"""Offline configuration checks; no SSH, tool installation, or active-state writes."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

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
        for key in ("SSH_CONNECTION", "SSH_TTY", "NVIM_APPNAME", "NVIM_REMOTE_DEV", "__MISE_ORIG_PATH", "VIRTUAL_ENV"):
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
            CLAUDE_CONFIG_DIR=str(self.root / "claude"),
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
            capture_output=True, text=True, timeout=30, check=False,
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
                    'local plugins=require("lazy.core.config").plugins; '
                    'for _, name in ipairs({"aerial.nvim","nvim-ufo","toggleterm.nvim","tiny-inline-diagnostic.nvim","promise-async"}) do '
                    'assert(plugins[name]==nil, name); end; '
                    'assert(vim.diagnostic.config().virtual_text and not vim.diagnostic.config().virtual_lines); '
                    'if not environment.remote then '
                    'local cc=require("claudecode"); assert(cc.state.initialized and cc.state.server); '
                    'assert(cc.state.config.terminal.provider=="none"); '
                    'for _, key in ipairs({"ac","af","ar","aC","am"}) do '
                    'assert(vim.fn.maparg("<Space>" .. key,"n")==""); end; '
                    'require("lazy").load({plugins={"nvim-dap","neotest","overseer.nvim"}}); '
                    'assert(require("dap").listeners.on_config.overseer); '
                    'assert(require("dap.ext.vscode").json_decode~=vim.json.decode); '
                    'assert(package.loaded.neotest); '
                    'else assert(not package.loaded.claudecode and not package.loaded.dap); end; '
                    'for _, buf in ipairs(vim.api.nvim_list_bufs()) do '
                    'assert(vim.bo[buf].buftype~="terminal", "embedded terminal was created"); end; '
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

    def test_statusline_project_diagnostics_and_empty_metadata(self):
        for name in ("project", "project-other"):
            (self.root / name / ".git").mkdir(parents=True)
        self.run_lua(
            'local root=' + json.dumps(str(self.root)) + r''';
local buffers={}
for i, name in ipairs({"project/a.txt", "project/b.txt", "project-other/c.txt"}) do
  local b=vim.fn.bufadd(root .. "/" .. name); vim.fn.bufload(b); buffers[i]=b
end
local ns=vim.api.nvim_create_namespace("test")
vim.diagnostic.set(ns,buffers[1],{{lnum=0,col=0,message="a",severity=vim.diagnostic.severity.ERROR}})
vim.diagnostic.set(ns,buffers[2],{{lnum=0,col=0,message="b",severity=vim.diagnostic.severity.ERROR}})
vim.diagnostic.set(ns,buffers[3],{{lnum=0,col=0,message="c",severity=vim.diagnostic.severity.WARN}})
vim.api.nvim_set_current_buf(buffers[1])
local editor=require("statusline.editor")
assert(editor.diagnostics():find("2",1,true),editor.diagnostics())
assert(not editor.diagnostics():find("1",1,true),editor.diagnostics())
assert(editor.language("") == "text")
assert(editor.encoding("") == vim.o.encoding:upper())
vim.api.nvim_buf_set_lines(buffers[1],0,-1,false,{"あa"})
vim.api.nvim_win_set_cursor(0,{1,3})
assert(editor.position() == "Ln1, Col4")
vim.api.nvim_set_current_buf(buffers[3])
assert(editor.diagnostics():find("1",1,true),editor.diagnostics())
assert(not editor.diagnostics():find("2",1,true),editor.diagnostics())
''')

    @unittest.skipUnless(shutil.which("mise"), "mise is required")
    def test_runtime_versions_follow_projects_and_invalidate(self):
        for index, version in enumerate(("v20.1.0", "v22.2.0", "v24.3.0")):
            binary = self.root / f"runtime{index}/bin/node"
            binary.parent.mkdir(parents=True)
            binary.write_text("#!/bin/sh\nprintf '%s\\n' '" + version + "'\n")
            binary.chmod(0o755)
        for index in range(2):
            project = self.root / f"project{index}"
            project.mkdir()
            (project / "mise.toml").write_text(
                '[tools]\nnode = "path:' + str(self.root / f"runtime{index}") + '"\n'
            )
        self.run_lua(
            'local root=' + json.dumps(str(self.root)) + r''';
local original_path=vim.env.PATH
vim.env.__MISE_ORIG_PATH=original_path
vim.env.PATH=root .. "/runtime0/bin:" .. original_path
local a=vim.fn.bufadd(root .. "/project0/a.js")
local b=vim.fn.bufadd(root .. "/project1/b.js")
local runtime=require("statusline.runtime")
runtime.setup()
runtime.version("javascript",a);runtime.version("javascript",b)
assert(vim.wait(10000,function()
  return runtime.version("javascript",a)=="v20.1.0" and runtime.version("javascript",b)=="v22.2.0"
end), "project runtime selection failed")
vim.fn.writefile({'[tools]', 'node = "path:' .. root .. '/runtime2"'},root .. "/project1/mise.toml")
vim.api.nvim_exec_autocmds("BufWritePost",{pattern=root .. "/project1/mise.toml"})
assert(vim.wait(10000,function() return runtime.version("javascript",b)=="v24.3.0" end), "stale runtime cache")
assert(vim.wait(10000,function() return runtime.version("javascript",a)=="v20.1.0" end))
''', environment={"MISE_TRUSTED_CONFIG_PATHS": str(self.root), "MISE_OFFLINE": "1"})

    def test_runtime_deduplicates_queries_and_discards_old_results(self):
        self.run_lua(r'''
local pending={}
vim.system=function(argv,opts,callback)
  assert(opts.env.MISE_EXEC_AUTO_INSTALL == "0")
  assert(opts.env.MISE_NOT_FOUND_AUTO_INSTALL == "0")
  pending[#pending+1]=callback
end
local runtime=require("statusline.runtime")
runtime.version("python");runtime.version("python")
assert(#pending==1)
runtime.clear()
runtime.version("python")
assert(#pending==2)
pending[2]({code=0,stdout="Python 3.14.0"});vim.wait(10)
pending[1]({code=0,stdout="Python 3.9.0"});vim.wait(10)
assert(runtime.version("python")=="3.14.0")
''')

    def test_auto_save_writes_files_and_reports_failure(self):
        self.run_lua(
            'local root=' + json.dumps(str(self.root)) + r''';
require("config.autocmds")
vim.cmd.edit(root .. "/saved.txt")
vim.api.nvim_buf_set_lines(0,0,-1,false,{"saved"})
vim.api.nvim_exec_autocmds("FocusLost",{modeline=false})
assert(vim.fn.readfile(root .. "/saved.txt")[1]=="saved")
assert(not vim.bo.modified)
vim.cmd.edit(root .. "/missing/directory/file.txt")
vim.api.nvim_buf_set_lines(0,0,-1,false,{"keep me"})
local failure
vim.notify=function(message,level) if level==vim.log.levels.ERROR then failure=message end end
vim.api.nvim_exec_autocmds("FocusLost",{modeline=false})
assert(failure and failure:find("自動保存に失敗",1,true))
assert(vim.bo.modified)
''')

    def test_contest_shortcuts_use_native_terminal_and_project_tasks(self):
        self.run_lua(r'''
local calls={}
vim.fn.jobstart=function(argv,opts) calls[#calls+1]={argv=argv,opts=opts};return 1 end
vim.cmd.edit(vim.env.HOME .. "/main.cpp")
vim.api.nvim_buf_set_lines(0,0,-1,false,{"int main() {}"})
require("config.keymaps.contest")
local keys=vim.api.nvim_get_keymap("n")
for _, key in ipairs(keys) do
  if key.desc=="AtCoder: sample test" then key.callback();break end
end
assert(#calls==1 and calls[1].opts.term)
assert(calls[1].argv[3]=="mise run test")
assert(calls[1].opts.cwd==vim.env.HOME)
assert(vim.fn.readfile(vim.env.HOME .. "/main.cpp")[1]=="int main() {}")
assert(not package.loaded.overseer and not package.loaded.toggleterm)
''')

    @unittest.skipUnless((LAZY / "lualine.nvim").is_dir(), "installed lualine is required")
    def test_statusline_renders_metadata_in_each_window(self):
        self.run_lua(
            'vim.opt.rtp:append(' + json.dumps(str(LAZY / "lualine.nvim")) + '); '
            'vim.opt.rtp:append(' + json.dumps(str(LAZY / "mini.icons")) + '); '
            'local config=' + json.dumps(str(CONFIG)) + r''';
require("mini.icons").setup();require("mini.icons").mock_nvim_web_devicons()
vim.o.columns=240
local a=vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(a,vim.env.HOME .. "/a.lua")
vim.bo[a].filetype="lua";vim.bo[a].expandtab=true;vim.bo[a].shiftwidth=2
local win_a=vim.api.nvim_get_current_win()
vim.cmd.vsplit()
local win_b=vim.api.nvim_get_current_win()
local b=vim.api.nvim_create_buf(true,false)
vim.api.nvim_win_set_buf(win_b,b)
vim.api.nvim_buf_set_name(b,vim.env.HOME .. "/b.py")
vim.bo[b].filetype="python"
package.loaded["statusline.runtime"]={setup=function() end,os_info=function() return "TEST_OS" end,
version=function(_,buf) return buf==a and "VERSION_A" or "VERSION_B" end}
dofile(config .. "/lua/plugins/lualine.lua")[1].config()
local function render(win)
  return vim.api.nvim_win_call(win,function()
    return vim.api.nvim_eval_statusline(require("lualine").statusline(),{winid=win,maxwidth=240}).str
  end)
end
local left=render(win_a);local right=render(win_b)
assert(left:find("VERSION_A",1,true) and not left:find("VERSION_B",1,true),left)
assert(right:find("VERSION_B",1,true) and not right:find("VERSION_A",1,true),right)
for _, text in ipairs({"TEST_OS","Space 2","UTF-8","LF","Ln1, Col1"}) do
  assert(left:find(text,1,true),text .. ": " .. left)
end
assert(left:match("%d%d:%d%d"),left)
''')

    @unittest.skipUnless((LAZY / "overseer.nvim").is_dir(), "installed Overseer is required")
    def test_builtin_just_template_keeps_arguments_cwd_and_quickfix(self):
        (self.root / "justfile").write_text("sample target:\n    echo {{target}}\n")
        nested = self.root / "nested"
        nested.mkdir()
        self.run_lua(
            'vim.opt.rtp:append(' + json.dumps(str(LAZY / "overseer.nvim")) + '); '
            'local spec=dofile(' + json.dumps(str(CONFIG / "lua/plugins/overseer.lua")) + r''')[1];
spec.config(nil,spec.opts)
local root=vim.env.HOME
local executable=vim.fn.executable
vim.fn.executable=function(name) return name=="just" and 1 or executable(name) end
require("overseer").builtin.system=function(argv,opts,cb)
  assert(argv[1]=="just" and opts.cwd==root)
  cb({code=0,stdout=vim.json.encode({recipes={sample={namepath="sample",private=false,
    parameters={{name="target",kind="singular"}}}},modules={}})})
end
local templates
require("overseer.template.just").generator({dir=root .. "/nested"},function(items) templates=items end)
assert(vim.wait(1000,function() return templates~=nil end))
assert(#templates==1 and templates[1].name=="just sample")
templates[1].module="just"
local result
require("overseer.template").build_task_args(templates[1],{
  params={target="hello"},search={dir=root .. "/nested"},disallow_prompt=true,
},function(err,args) assert(not err,err); result=args end)
assert(result and vim.deep_equal(result.cmd,{"just","sample","hello"}))
assert(result.cwd==root)
local count=0
for _, c in ipairs(result.components) do
  if c=="on_output_quickfix" or type(c)=="table" and c[1]=="on_output_quickfix" then count=count+1 end
end
assert(count==1,"quickfix hook missing or duplicated")
''')

    def test_runtime_display_uses_project_and_activated_python_venvs(self):
        for name, version in (("project-a", "3.12.1"), ("project-b", "3.13.2"), ("activated", "3.14.3")):
            root = self.root / name
            binary = root / ".venv/bin/python"
            binary.parent.mkdir(parents=True)
            binary.write_text("#!/bin/sh\nprintf '%s\\n' 'Python " + version + "'\n")
            binary.chmod(0o755)
            (root / "pyproject.toml").write_text("")
        self.run_lua(r'''
local root=vim.env.HOME
local a=vim.fn.bufadd(root .. "/project-a/main.py")
local b=vim.fn.bufadd(root .. "/project-b/main.py")
local runtime=require("statusline.runtime")
assert(vim.wait(5000,function()
  return runtime.version("python",a)=="3.12.1" and runtime.version("python",b)=="3.13.2"
end))
vim.env.VIRTUAL_ENV=root .. "/activated/.venv"
assert(vim.wait(5000,function()
  return runtime.version("python",a)=="3.14.3" and runtime.version("python",b)=="3.14.3"
end), "activated venv was ignored or cached version leaked")
''')

    def test_native_folds_use_treesitter_or_indent_without_a_parser(self):
        self.run_lua(
            'local executable=vim.fn.executable; vim.fn.executable=function(name) '
            'if name=="cc" or name=="tree-sitter" then return 0 end;return executable(name) end; '
            'require("config.options"); dofile(' + json.dumps(str(CONFIG / "lua/plugins/treesitter.lua")) + r''')[1].config()
vim.api.nvim_buf_set_lines(0,0,-1,false,{"local function sample()", "  return true", "end"})
vim.bo.filetype="lua"
assert(vim.wo.foldmethod=="expr", "Lua parser folding unavailable")
assert(vim.wo.foldexpr=="v:lua.vim.treesitter.foldexpr()")
vim.bo.filetype="test_language_without_parser"
assert(vim.wo.foldmethod=="indent", "missing parser must fall back to indent")
assert(vim.fn.maparg("zR","n")=="" and vim.fn.maparg("zM","n")=="")
''')

    def test_auto_format_skips_large_and_special_buffers(self):
        (self.root / "small.lua").write_text("local x=1\n")
        (self.root / "large.lua").write_bytes(b" " * (1024 * 1024 + 1))
        self.run_lua(
            'local format=dofile(' + json.dumps(str(CONFIG / "lua/plugins/conform.lua")) + r''')[1].opts.format_on_save
local small=vim.fn.bufadd(vim.env.HOME .. "/small.lua")
local large=vim.fn.bufadd(vim.env.HOME .. "/large.lua")
vim.fn.bufload(small);vim.fn.bufload(large)
assert(format(small).timeout_ms==1000)
assert(format(large)==nil, "large files must not be formatted automatically")
local unnamed=vim.api.nvim_create_buf(true,false)
assert(format(unnamed)==nil)
local special=vim.api.nvim_create_buf(false,true)
vim.api.nvim_buf_set_name(special,"special.lua")
vim.bo[special].filetype="lua"
assert(format(special)==nil)
''')


if __name__ == "__main__":
    unittest.main()
