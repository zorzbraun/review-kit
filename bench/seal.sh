#!/bin/bash
# Zapecati review folder za benchmark: kod se kopira bez .git, a git worktree se odmah uklanja.
# Tako reviewer ne moze kroz git istoriju da vidi revert ili popravku koja je dosla posle.
#   seal.sh <OUT iz target.sh>
set -uo pipefail
OUT="${1:-}"
[ -f "$OUT/context.env" ] || { echo "upotreba: seal.sh <OUT>" >&2; exit 1; }
source "$OUT/context.env"
SEALED="$OUT/sealed"
rsync -a --exclude .git "$WORKTREE/" "$SEALED/" || { echo "GRESKA: kopija nije uspela" >&2; exit 1; }
if [ "$WORKTREE" != "$REPO" ]; then
  git -C "$REPO" worktree remove --force "$WORKTREE" || { echo "GRESKA: worktree nije uklonjen" >&2; exit 1; }
fi
git -C "$REPO" update-ref -d "refs/review-kit/$ID" 2>/dev/null || true
# reviewer ne sme da zna ni putanju pravog repoa; cleanup posle ovoga brise samo OUT
sed -i '' -e "s#^WORKTREE=.*#WORKTREE=$(printf '%q' "$SEALED")#" \
          -e "s#^REPO=.*#REPO=$(printf '%q' "$SEALED")#" -e "/^REMOTE=/d" "$OUT/context.env"
echo "SEALED: $SEALED"
