#!/bin/bash
# Approve MR/PR. Zove se SAMO posle izricitog "da" od korisnika u istoj poruci, nikad automatski.
#   approve.sh <OUT>
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-}"
[ -f "$OUT/context.env" ] || { echo "upotreba: approve.sh <OUT>" >&2; exit 1; }
source "$OUT/context.env"
[ "$KIND" = pr ] || { echo "GRESKA: cilj nije MR/PR" >&2; exit 1; }
PLAT=$(jq -r .platform "$OUT/meta.json")
source "$KIT/adapters/lib/$PLAT.sh"
live=$(platform_head "$ID") || { echo "GRESKA: ne mogu da procitam head" >&2; exit 1; }
[ "$live" = "$HEAD_SHA" ] || { echo "GRESKA: head se promenio (${HEAD_SHA:0:8} -> ${live:0:8}), approve nije dat" >&2; exit 1; }
platform_approve "$ID" >/dev/null || { echo "GRESKA: approve nije prosao" >&2; exit 1; }
echo "ODOBRENO: $(jq -r .url "$OUT/meta.json")"
