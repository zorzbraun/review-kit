#!/bin/bash
# Pretvara cilj review-a u folder sa diff-om, meta podacima i (za MR/PR) izolovanim worktree-om.
#
#   target.sh                    lokalne izmene (commit-ovane i ne) u odnosu na base granu
#   target.sh 123 | !123 | #123  MR ili PR, platforma iz profila
#   target.sh <URL MR-a ili PR-a>
#   target.sh <grana ili commit>
#   opcije: --base <grana>  --repo <putanja>  --no-worktree  --out <folder>
#
# Ispis su "KLJUC: vrednost" linije; isto stoji u $OUT/context.env za source.
# U repou menja samo refs/review-kit/* i dodaje detached worktree.
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="" BASE_ARG="" REPO_ARG="$(pwd)" MAKE_WT=1 OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE_ARG="${2:-}"; shift 2 ;;
    --repo) REPO_ARG="${2:-}"; shift 2 ;;
    --no-worktree) MAKE_WT=0; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -*) echo "GRESKA: nepoznata opcija $1" >&2; exit 1 ;;
    *) [ -z "$TARGET" ] || { echo "GRESKA: visak argumenta: $1" >&2; exit 1; }; TARGET="$1"; shift ;;
  esac
done

die() { echo "GRESKA: $*" >&2; [ -n "${OUT_CREATED:-}" ] && rm -rf "$OUT"; exit 1; }

PROFILE_OUT=$("$KIT/adapters/profile.sh" "$REPO_ARG") || exit 1
eval "$PROFILE_OUT"

KIND="" ID=""
case "$TARGET" in
  "") KIND=local; ID=local ;;
  http*://*/merge_requests/*) KIND=pr; PLATFORM=gitlab ;;
  http*://github.com/*/pull/*) KIND=pr; PLATFORM=github ;;
  http*) die "ne prepoznajem URL: $TARGET" ;;
  \!*|\#*|[0-9]*)
    n="${TARGET#!}"; n="${n#\#}"
    # do 6 cifara je uvek MR/PR broj; skraceni sha ima bar 7 znakova
    if [[ "$n" =~ ^[0-9]{1,6}$ ]]; then KIND=pr; ID="$n"; else KIND=ref; fi ;;
  *) KIND=ref ;;
esac

if [ "$KIND" = pr ]; then
  case "$PLATFORM" in
    gitlab|github) source "$KIT/adapters/lib/$PLATFORM.sh" ;;
    *) die "repo nema poznatu platformu (origin: ${REMOTE:-nema}), MR/PR broj ne moze da se razresi" ;;
  esac
  if [[ "$TARGET" == http* ]]; then
    project=$(url_project "$TARGET")
    printf '%s' "$REMOTE" | grep -qF "$project" || die "URL je za $project, a repo $REPO je klon ${REMOTE}; pokreni iz pravog repoa ili dodaj --repo"
    ID=$(url_id "$TARGET")
  fi
fi

if [ -z "$OUT" ]; then OUT=$(mktemp -d -t review-kit); OUT_CREATED=1; else mkdir -p "$OUT"; fi

case "$KIND" in
  pr)
    platform_meta "$ID" > "$OUT/meta.json" 2>"$OUT/meta.err" || die "ne mogu da procitam MR/PR $ID ($(head -1 "$OUT/meta.err"))"
    BASE="${BASE_ARG:-$(jq -r .base "$OUT/meta.json")}"
    HEAD_SHA=$(jq -r .head_sha "$OUT/meta.json")
    if ! git -C "$REPO" fetch --quiet origin "+$(platform_ref "$ID"):refs/review-kit/$ID" "$BASE" 2>/dev/null; then
      # platforma ume da obrise ref starog MR-a; sam commit se i dalje moze povuci po sha-u
      git -C "$REPO" fetch --quiet origin "$HEAD_SHA" "$BASE" 2>/dev/null \
        && git -C "$REPO" update-ref "refs/review-kit/$ID" "$HEAD_SHA" \
        || die "fetch MR/PR $ID nije prosao (VPN, login ili pogresan broj)"
      echo "NAPOMENA: ref MR/PR-a ne postoji na origin-u, povucen je commit $HEAD_SHA direktno"
    fi
    FETCHED=$(git -C "$REPO" rev-parse "refs/review-kit/$ID")
    if [ "$FETCHED" != "$HEAD_SHA" ]; then
      echo "NAPOMENA: platforma kaze $HEAD_SHA, a ref je $FETCHED (push u medjuvremenu?); koristim ref"
      HEAD_SHA="$FETCHED"
    fi
    ;;
  ref)
    BASE="${BASE_ARG:-$BASE}"
    git -C "$REPO" fetch --quiet origin "$BASE" 2>/dev/null || echo "NAPOMENA: fetch $BASE nije prosao, origin/$BASE je mozda zastareo"
    # pun sha koji jos nije lokalno (npr. stari commit iz benchmark-a) se povlaci direktno
    if [[ "$TARGET" =~ ^[0-9a-f]{40}$ ]] && ! git -C "$REPO" cat-file -e "$TARGET^{commit}" 2>/dev/null; then
      git -C "$REPO" fetch --quiet origin "$TARGET" 2>/dev/null || true
    fi
    HEAD_SHA=$(git -C "$REPO" rev-parse --verify --quiet "$TARGET^{commit}" \
      || git -C "$REPO" rev-parse --verify --quiet "origin/$TARGET^{commit}") || die "ne postoji grana ni commit: $TARGET"
    ID="$TARGET"
    git -C "$REPO" log -1 --format='%s%x00%an%x00%b' "$HEAD_SHA" | jq -R -s --arg id "$ID" --arg base "$BASE" --arg sha "$HEAD_SHA" '
      split("\u0000") | {platform: "git", id: $id, title: .[0], description: (.[2] // ""), author: .[1],
      url: null, base: $base, head_sha: $sha, state: null, source_branch: $id}' > "$OUT/meta.json"
    ;;
  local)
    BASE="${BASE_ARG:-$BASE}"
    git -C "$REPO" fetch --quiet origin "$BASE" 2>/dev/null || echo "NAPOMENA: fetch $BASE nije prosao, origin/$BASE je mozda zastareo"
    HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)
    branch=$(git -C "$REPO" branch --show-current)
    jq -n --arg base "$BASE" --arg sha "$HEAD_SHA" --arg b "${branch:-detached}" \
      --arg author "$(git -C "$REPO" config user.name || true)" '{platform: "local", id: "local",
      title: ("lokalne izmene na " + $b), description: "", author: $author, url: null, base: $base,
      head_sha: $sha, state: null, source_branch: $b}' > "$OUT/meta.json"
    MAKE_WT=0
    ;;
esac

BASE_REF="origin/$BASE"
git -C "$REPO" rev-parse --verify --quiet "$BASE_REF" >/dev/null || BASE_REF="$BASE"
git -C "$REPO" rev-parse --verify --quiet "$BASE_REF" >/dev/null || die "base grana $BASE ne postoji ni lokalno ni na origin-u"
# merge-ovan MR/PR je vec u base grani, pa bi diff prema danasnjem vrhu bio prazan;
# zato osnova ide od commit-a od kog platforma sama racuna diff
ANCHOR="$BASE_REF"
PLATFORM_BASE=$(jq -r '.base_sha // empty' "$OUT/meta.json")
if [ -n "$PLATFORM_BASE" ]; then
  if git -C "$REPO" cat-file -e "$PLATFORM_BASE^{commit}" 2>/dev/null \
     || git -C "$REPO" fetch --quiet origin "$PLATFORM_BASE" 2>/dev/null; then
    ANCHOR="$PLATFORM_BASE"
  fi
fi
MERGE_BASE=$(git -C "$REPO" merge-base "$ANCHOR" "$HEAD_SHA") || die "nema zajednickog pretka sa $ANCHOR"

if [ "$KIND" = local ]; then
  # radni direktorijum, ne HEAD: hvata i necommit-ovano
  DIFF_ARGS=("$MERGE_BASE")
  git -C "$REPO" ls-files --others --exclude-standard > "$OUT/untracked.txt"
else
  DIFF_ARGS=("$MERGE_BASE" "$HEAD_SHA")
fi
git -C "$REPO" diff "${DIFF_ARGS[@]}" > "$OUT/diff.patch"
git -C "$REPO" diff --name-status "${DIFF_ARGS[@]}" > "$OUT/name-status.txt"
git -C "$REPO" diff --stat "${DIFF_ARGS[@]}" > "$OUT/stat.txt"
git -C "$REPO" log --oneline "$MERGE_BASE..$HEAD_SHA" > "$OUT/commits.txt"

FILES=$(grep -c . "$OUT/name-status.txt" || true)
LINES=$(grep -c . "$OUT/diff.patch" || true)
UNTRACKED=$( [ -f "$OUT/untracked.txt" ] && grep -c . "$OUT/untracked.txt" || echo 0 )
[ "$FILES" -gt 0 ] || [ "$UNTRACKED" -gt 0 ] || die "diff je prazan u odnosu na $BASE_REF"

WORKTREE="$REPO"
if [ "$MAKE_WT" = 1 ]; then
  safe_id=$(printf '%s' "$ID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-30)
  WORKTREE="$WORKTREE_DIR/rk-$(basename "$REPO")-$safe_id-${HEAD_SHA:0:7}"
  if [ -d "$WORKTREE" ]; then
    echo "NAPOMENA: worktree vec postoji, koristim ga"
  else
    mkdir -p "$WORKTREE_DIR"
    git -C "$REPO" worktree add --detach --quiet "$WORKTREE" "$HEAD_SHA" 2>"$OUT/wt.err" \
      || die "worktree add nije prosao: $(head -1 "$OUT/wt.err")"
  fi
fi

{
  printf '%s\n' "$PROFILE_OUT"
  for k in KIND ID HEAD_SHA MERGE_BASE BASE OUT WORKTREE FILES LINES UNTRACKED; do printf '%s=%q\n' "$k" "${!k}"; done
} > "$OUT/context.env"

for k in PROFILE_NAME PLATFORM KIND ID BASE HEAD_SHA FILES LINES UNTRACKED WORKTREE OUT; do
  printf '%s: %s\n' "$k" "${!k}"
done
printf 'TITLE: %s\n' "$(jq -r .title "$OUT/meta.json")"
printf 'CLEANUP: %s/adapters/cleanup.sh %s\n' "$KIT" "$OUT"
