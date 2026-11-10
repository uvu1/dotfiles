# cd / cdi を zoxide に置き換える。補完の compdef は compinit 済みでないと
# 登録されないため、sheldon では completion より後に読み込む。
eval "$(zoxide init zsh --cmd cd)"
