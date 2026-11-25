#!/bin/bash
# Pravi symlinkove iz ~/.claude u ovaj repo i folder ~/.review-kit za profile, worktree-ove i dnevnik.
# Moze da se pokrece koliko god puta.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/.review-kit/profiles" "$HOME/.review-kit/worktrees" "$HOME/.review-kit/log" \
         "$HOME/.claude/skills" "$HOME/.claude/agents"

link() { # link <izvor> <odrediste>
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    echo "GRESKA: $2 postoji i nije symlink, premesti ga rucno" >&2
    exit 1
  fi
  ln -sfn "$1" "$2"
  echo "ok: $(basename "$2")"
}

for dir in "$KIT"/skills/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  link "${dir%/}" "$HOME/.claude/skills/$(basename "$dir")"
done
for f in "$KIT"/agents/*.md; do
  [ -e "$f" ] || continue
  link "$f" "$HOME/.claude/agents/$(basename "$f")"
done
chmod +x "$KIT"/adapters/*.sh

echo
echo "Profili se traze u ~/.review-kit/profiles (firmini profili se tamo linkuju iz svog repoa)."
echo "Restartuj Claude Code da ucita skill-ove."
