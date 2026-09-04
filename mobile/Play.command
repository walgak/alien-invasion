#!/bin/zsh
set -eu
project_dir="${0:A:h}"
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
else
  print "Install Godot 4.7, then open project.godot and press F5."
  read "reply?Press Return to close."
  exit 1
fi
if [[ ! -d "$project_dir/.godot/imported" ]]; then
  "$godot_bin" --headless --path "$project_dir" --editor --import --quit
fi
exec "$godot_bin" --path "$project_dir"
