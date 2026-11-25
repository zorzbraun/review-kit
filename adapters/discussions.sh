#!/bin/bash
# Ispise komentare sa MR/PR-a kao JSON (samo citanje). Za lokalne izmene i grane vraca [].
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-}"
[ -f "$OUT/context.env" ] || { echo "upotreba: discussions.sh <OUT>" >&2; exit 1; }
source "$OUT/context.env"
if [ "$KIND" != pr ]; then echo "[]"; exit 0; fi
source "$KIT/adapters/lib/$(jq -r .platform "$OUT/meta.json").sh"
platform_discussions "$ID"
