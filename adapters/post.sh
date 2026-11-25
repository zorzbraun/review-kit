#!/bin/bash
# Kaci review na MR/PR. Skill ga zove samo kad je to dozvoljeno (deep-review: posle post_gate.py).
#   post.sh <OUT> <zbirni komentar> [--inline <post-plan.json>]
# Pre kacenja jos jednom proverava head uzivo. Inline komentar koji platforma odbije ide u zbirni.
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-}" BODY="${2:-}" PLAN=""
[ "${3:-}" = "--inline" ] && PLAN="${4:-}"
[ -f "$OUT/context.env" ] && [ -s "$BODY" ] || { echo "upotreba: post.sh <OUT> <fajl sa telom> [--inline <post-plan.json>]" >&2; exit 1; }
source "$OUT/context.env"
[ "$KIND" = pr ] || { echo "GRESKA: cilj nije MR/PR, nema gde da se okaci" >&2; exit 1; }
PLAT=$(jq -r .platform "$OUT/meta.json")
source "$KIT/adapters/lib/$PLAT.sh"

live=$(platform_head "$ID") || { echo "GRESKA: ne mogu da procitam head MR/PR-a" >&2; exit 1; }
[ "$live" = "$HEAD_SHA" ] || { echo "GRESKA: head se promenio (${HEAD_SHA:0:8} -> ${live:0:8}), nista nije okaceno" >&2; exit 1; }

FINAL="$OUT/comment.final.md"
cp "$BODY" "$FINAL"
posted=0 failed=0
if [ -n "$PLAN" ]; then
  [ -s "$PLAN" ] || { echo "GRESKA: plan $PLAN ne postoji" >&2; exit 1; }
  base=$(jq -r .base_sha "$OUT/meta.json") start=$(jq -r '.start_sha // .base_sha' "$OUT/meta.json")
  n=$(jq '.inline | length' "$PLAN")
  for ((i = 0; i < n; i++)); do
    file=$(jq -r ".inline[$i].file" "$PLAN") line=$(jq -r ".inline[$i].line" "$PLAN")
    tmp="$OUT/inline-$i.md"
    jq -r ".inline[$i].body" "$PLAN" > "$tmp"
    if id=$(platform_post_inline "$ID" "$file" "$line" "$tmp" "$base" "$start" "$HEAD_SHA" 2>/dev/null) && [ -n "$id" ]; then
      posted=$((posted + 1))
    else
      failed=$((failed + 1))
      [ "$failed" = 1 ] && printf '\n**Could not anchor inline**\n\n' >> "$FINAL"
      { echo "- \`$file:$line\`"; sed 's/^/  /' "$tmp"; } >> "$FINAL"
    fi
  done
fi

id=$(platform_post "$ID" "$FINAL") || { echo "GRESKA: zbirni komentar nije okacen (inline okaceno: $posted)" >&2; exit 1; }
[ -n "$id" ] || { echo "GRESKA: platforma nije vratila id komentara, proveri rucno" >&2; exit 1; }
echo "OKACENO: zbirni $id, inline $posted, neuspelih inline $failed (prebaceni u zbirni) na $(jq -r .url "$OUT/meta.json")"
