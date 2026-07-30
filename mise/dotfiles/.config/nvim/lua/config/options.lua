vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.termguicolors = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true

vim.opt.pumblend = 10
vim.opt.winblend = 10

-- フロート枠の正本。blink・overseer・vim.lsp.util.open_floating_preview は
-- border 未指定なら winborder を読むので、プラグイン側に "rounded" を書かない。
-- 追従しない例外が 2 つある: toggleterm（"single" ハードコード）と
-- noice（自前既定が "rounded"）。どちらも各ファイルにコメントを置いた。
vim.opt.winborder = "rounded"
vim.opt.pumborder = "rounded"

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.updatetime = 300

-- 再起動をまたいで undo を残す。
-- 'confirm' は入れない。未保存バッファでの :q は vim 既定どおり E37 で失敗させる
-- （プロンプトを出すと :q / :q! の使い分けという vim の操作感が変わるため）。
vim.opt.undofile = true

vim.opt.clipboard = "unnamedplus"

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitbelow = true
vim.opt.splitright = true

-- 下部に端末やタスク一覧が開いても本文のスクロール位置をずらさない。
vim.opt.splitkeep = "screen"

-- view を足すと <C-o>/<C-i> がスクロール位置ごと復元する（VSCode の Alt+Left/Right）。
vim.opt.jumpoptions = "clean,view"

-- 既定の blank と terminal を落とす。:mksession が explorer/picker の
-- スクラッチウィンドウと toggleterm の端末まで記録してしまい、
-- 復元時に空の無名バッファや壊れた端末になるため。
vim.opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,localoptions"

-- for WSL
if vim.fn.has("wsl") == 1 then
  if vim.fn.executable("wl-copy") == 0 then
    print("wl-copy is not installed, clipboard integration will not work")
  else
    vim.g.clipboard = {
      name = "wl-clipboard(wsl)",
      copy = {
        ["+"] = "wl-copy --foreground --type text/plain",
        ["*"] = "wl-copy --foreground --primary --type text/plain",
      },
      paste = {
        ["+"] = function()
          return vim.fn.systemlist('wl-paste --no-newline|sed -e "s/\r$//"', { "" }, 1)
        end,
        ["*"] = function()
          return vim.fn.systemlist('wl-paste --no-newline --primary|sed -e "s/\r$//"', { "" }, 1)
        end,
      },
      cache_enabled = true,
    }
  end
end

-- LSP / formatter の実体は nix profile にあり、デスクトップランチャ等から起動しても
-- そこは PATH に載る。ここで補うのは mise がグローバルに宣言している分（dotflow と
-- vendor CLI）だけで、シェルを経由しない起動でもそれらを解決できるようにする。
-- append にして、既に載っている具体パスの解決を優先させる。
do
  local shims = vim.fs.joinpath(vim.uv.os_homedir(), ".local/share/mise/shims")
  if vim.uv.fs_stat(shims) and not vim.env.PATH:find(shims, 1, true) then
    vim.env.PATH = vim.env.PATH .. ":" .. shims
  end
end
