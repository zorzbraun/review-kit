#!/bin/bash
# Uklanja ono sto je target.sh napravio: worktree (samo rk-* detached) i privremeni folder.
set -uo pipefail
OUT="${1:-}"
[ -f "$OUT/context.env" ] || { echo "upotreba: cleanup.sh <OUT folder iz target.sh>" >&2; exit 1; }
source "$OUT/context.env"

if [ "$WORKTREE" != "$REPO" ] && [[ "$WORKTREE" != "$OUT"/* ]]; then
  case "$(basename "$WORKTREE")" in
    rk-*) ;;
    *) echo "GRESKA: odbijam da uklonim $WORKTREE, nije review-kit worktree" >&2; exit 1 ;;
  esac
  if [ -d "$WORKTREE" ]; then
    # detached je, nema grane ni commit-a koji se gube
    git -C "$REPO" worktree remove --force "$WORKTREE" && echo "UKLONJEN: $WORKTREE"
  fi
fi
git -C "$REPO" update-ref -d "refs/review-kit/$ID" 2>/dev/null || true
case "$OUT" in
  */review-kit.*) rm -rf "$OUT" && echo "OBRISAN: $OUT" ;;
  *) echo "NAPOMENA: $OUT nije napravio target.sh, ostavljam ga" ;;
esac
