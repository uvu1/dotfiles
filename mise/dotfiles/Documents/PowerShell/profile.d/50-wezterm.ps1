# wezterm の mux 接続(unix domain)では ClientPane が foreground process を報告せず、
# mux の codec も working_dir しか運ばない。そのため tabbar.lua はタブ名を組み立てられない。
# mux を越えて伝搬する user_vars に、実行中のコマンドラインとシェル種別を流す。
# 変数名とエスケープシーケンスは wezterm 公式の shell integration に合わせてある。
# zsh 側の対応は ~/.config/zsh/wezterm.zsh。

function Set-WeztermUserVar {
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$Value = ""
    )

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
    [Console]::Write("$([char]27)]1337;SetUserVar=$Name=$encoded$([char]7)")
}

# シェル自身の名前。コマンドを実行していないタブはこれで表示される。
Set-WeztermUserVar -Name "WEZTERM_SHELL" -Value "pwsh"

# PowerShell に preexec は無いので、行が確定した時点で呼ばれる AddToHistoryHandler を使う。
# 既定と同じ $true (MemoryAndFile) を返すため履歴の挙動は変わらない。
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$Line)

    Set-WeztermUserVar -Name "WEZTERM_PROG" -Value $Line
    return $true
}

# プロンプトが出る = コマンドが終わったので空へ戻す。starship が 10-initialization.ps1 で
# 設定した prompt を退避してラップする。profile.d は名前順ロードなので 50- で後に来る。
if (-not (Test-Path Variable:Global:WeztermInnerPrompt)) {
    $Global:WeztermInnerPrompt = $Function:prompt

    function global:prompt {
        Set-WeztermUserVar -Name "WEZTERM_PROG" -Value ""
        & $Global:WeztermInnerPrompt
    }
}
