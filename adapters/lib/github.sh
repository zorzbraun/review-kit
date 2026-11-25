# GitHub: PR podaci preko gh-a ako postoji, inace javni API (radi samo za javne repoe).
platform_ref() { echo "refs/pull/$1/head"; }

github_slug() { printf '%s' "$REMOTE" | sed -E 's#.*github\.com[:/]##; s#\.git$##'; }

github_api() {
  if command -v gh >/dev/null; then
    gh api "repos/$(github_slug)/$1"
  else
    curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$(github_slug)/$1" \
      || { echo "GRESKA: GitHub API nije odgovorio; za privatne repoe instaliraj gh (brew install gh)" >&2; return 1; }
  fi
}

platform_meta() {
  github_api "pulls/$1" | jq '{
    platform: "github", id: (.number|tostring), title, description: .body, author: .user.login,
    url: .html_url, base: .base.ref, base_sha: .base.sha, head_sha: .head.sha,
    state: (if .merged_at then "merged" else .state end), source_branch: .head.ref
  }'
}

url_project() { printf '%s' "$1" | sed -E 's#^https?://github\.com/##; s#/pull/.*##'; }
url_id() { printf '%s' "$1" | sed -E 's#.*/pull/([0-9]+).*#\1#'; }

platform_discussions() {
  { github_api "pulls/$1/comments?per_page=100"; github_api "issues/$1/comments?per_page=100"; } | jq -s '[
    .[][] | {author: .user.login, body: (.body[0:500]), file: (.path // null), line: (.line // null),
             resolvable: (.path != null), resolved: false, replies: 0}]'
}

platform_post() {
  command -v gh >/dev/null || { echo "GRESKA: postovanje na GitHub trazi gh (brew install gh)" >&2; return 1; }
  gh api -X POST "repos/$(github_slug)/issues/$1/comments" --field "body=@$2" | jq -r '.id // empty'
}
