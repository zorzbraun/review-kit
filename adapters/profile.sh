#!/bin/bash
# Nadje profil za repo i ispise ga kao KLJUC=vrednost linije (spremno za eval).
# Profili su prost "kljuc: vrednost" yaml, liste su odvojene zarezom.
# Trazi se u $REVIEW_KIT_PROFILES (dvotackom odvojeni folderi), pa u ~/.review-kit/profiles,
# pa u profiles/ samog kita. Pobedjuje prvi ciji remote_match pogadja origin URL.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${1:-$(pwd)}"
REPO=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null) || { echo "GRESKA: $1 nije git repo" >&2; exit 1; }
REMOTE=$(git -C "$REPO" remote get-url origin 2>/dev/null || echo "")

get() { # get <fajl> <kljuc>
  awk -v k="$2" -F': *' '$1==k { sub(/^[^:]*: */, ""); sub(/[[:space:]]+#.*$/, ""); print; exit }' "$1"
}

PROFILE="$KIT/profiles/generic.yaml"
IFS=':' read -r -a DIRS <<< "${REVIEW_KIT_PROFILES:-$HOME/.review-kit/profiles}"
for dir in "${DIRS[@]}"; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*.yaml; do
    [ -e "$f" ] || continue
    pattern=$(get "$f" remote_match)
    if [ -n "$pattern" ] && [ -n "$REMOTE" ] && printf '%s' "$REMOTE" | grep -Eq "$pattern"; then
      PROFILE="$f"
      break 2
    fi
  done
done

emit() { printf '%s=%q\n' "$1" "$2"; }
val() { local v; v=$(get "$PROFILE" "$1"); printf '%s' "${v:-$2}"; }

platform=$(val platform auto)
if [ "$platform" = "auto" ]; then
  case "$REMOTE" in
    *github.com*) platform=github ;;
    *gitlab*) platform=gitlab ;;
    *) platform=none ;;
  esac
fi

base=$(val base_branch auto)
if [ "$base" = "auto" ]; then
  base=$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
  if [ -z "$base" ]; then
    for b in main master; do
      if git -C "$REPO" show-ref --quiet "refs/remotes/origin/$b"; then base=$b; break; fi
    done
  fi
  base=${base:-main}
fi

wt=$(val worktree_dir "~/.review-kit/worktrees")
wt="${wt/#\~/$HOME}"
[[ "$wt" = /* ]] || wt="$REPO/$wt"
log=$(val log "~/.review-kit/log/generic.jsonl")
log="${log/#\~/$HOME}"

emit PROFILE_NAME "$(val name generic)"
emit PROFILE_FILE "$PROFILE"
emit REPO "$REPO"
emit REMOTE "$REMOTE"
emit PLATFORM "$platform"
emit BASE "$base"
emit WORKTREE_DIR "$wt"
emit TEST_COMMAND "$(val test_command "")"
emit TEST_SELECTOR "$(val test_selector "")"
emit FORBIDDEN "$(val forbidden "")"
emit RULE_SOURCES "$(val rule_sources "")"
emit ENGINES "$(val engines kit)"
emit LOG "$log"
bench=$(val bench "")
emit BENCH "${bench/#\~/$HOME}"
