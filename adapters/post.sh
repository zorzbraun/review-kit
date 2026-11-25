#!/bin/bash
# Kaci jedan komentar na MR/PR. Skill ga zove SAMO posle izricitog odobrenja korisnika.
#   post.sh <OUT> <fajl sa telom>
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-}" BODY="${2:-}"
[ -f "$OUT/context.env" ] && [ -s "$BODY" ] || { echo "upotreba: post.sh <OUT> <fajl sa telom>" >&2; exit 1; }
source "$OUT/context.env"
[ "$KIND" = pr ] || { echo "GRESKA: cilj nije MR/PR, nema gde da se okaci" >&2; exit 1; }
PLAT=$(jq -r .platform "$OUT/meta.json")
source "$KIT/adapters/lib/$PLAT.sh"
id=$(platform_post "$ID" "$BODY") || { echo "GRESKA: postovanje nije proslo" >&2; exit 1; }
[ -n "$id" ] || { echo "GRESKA: platforma nije vratila id komentara, proveri rucno" >&2; exit 1; }
echo "OKACENO: komentar $id na $(jq -r .url "$OUT/meta.json")"
