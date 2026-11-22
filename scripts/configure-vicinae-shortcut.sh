# shellcheck shell=bash

kde_call() {
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel "$@"
}

# Qt::AltModifier | Qt::Key_Space
alt_space=134217760
vicinae=(org.uvu1.Vicinae.desktop _launch Vicinae "Launch Vicinae")
krunner=(org.kde.krunner.desktop _launch KRunner KRunner)

owner=$(kde_call getGlobalShortcutsByKey i "$alt_space")
case "$owner" in
  *'"org.uvu1.Vicinae.desktop"'*) exit 0 ;;
  *'"org.kde.krunner.desktop"'*)
    read -r -a existing <<< "$(kde_call shortcut as 4 "${krunner[@]}")"
    retained=()
    for key in "${existing[@]:2}"; do
      if [[ "$key" != "$alt_space" ]]; then
        retained+=("$key")
      fi
    done
    kde_call setForeignShortcut asai 4 "${krunner[@]}" "${#retained[@]}" "${retained[@]}"
    ;;
  'a(ssssssaiai) 0') ;;
  *)
    printf '%s\n' "Alt+Space is already assigned to another KDE action." >&2
    exit 1
    ;;
esac

# KGlobalAccelD flags: SetPresent (2) and NoAutoloading (4).
if ! kde_call doRegister as 4 "${vicinae[@]}" ||
   ! kde_call setShortcut asaiu 4 "${vicinae[@]}" 1 "$alt_space" 6 ||
   [[ "$(kde_call getGlobalShortcutsByKey i "$alt_space")" != *'"org.uvu1.Vicinae.desktop"'* ]]; then
  if [[ "${existing[0]:-}" == ai ]]; then
    kde_call setForeignShortcut asai 4 "${krunner[@]}" "${existing[@]:1}"
  fi
  exit 1
fi
