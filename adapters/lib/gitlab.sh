# GitLab: MR podaci preko glab-a (koristi svoj login i host iz remote-a).
platform_ref() { echo "refs/merge-requests/$1/head"; }

platform_meta() {
  command -v glab >/dev/null || { echo "GRESKA: glab nije instaliran" >&2; return 1; }
  (cd "$REPO" && glab api "projects/:fullpath/merge_requests/$1") | jq '{
    platform: "gitlab", id: (.iid|tostring), title, description, author: .author.username,
    url: .web_url, base: .target_branch, base_sha: .diff_refs.base_sha, start_sha: .diff_refs.start_sha, head_sha: .sha, state, source_branch
  }'
}

# iz URL-a .../<grupa>/<projekat>/-/merge_requests/<n>
url_project() { printf '%s' "$1" | sed -E 's#^https?://[^/]+/##; s#/-/merge_requests/.*##'; }
url_id() { printf '%s' "$1" | sed -E 's#.*/merge_requests/([0-9]+).*#\1#'; }

platform_discussions() {
  (cd "$REPO" && glab api "projects/:fullpath/merge_requests/$1/discussions?per_page=100") | jq '[
    .[] | .notes[0] as $n | select($n.system | not) | {
      author: $n.author.username, body: ($n.body[0:500]), file: ($n.position.new_path // null),
      line: ($n.position.new_line // null), resolvable: $n.resolvable, resolved: ($n.resolved // false),
      replies: ((.notes | length) - 1)
    }]'
}

# telo ide iz fajla (--field body=@fajl), pa ga shell nikad ne tumaci
platform_post() {
  (cd "$REPO" && glab api -X POST "projects/:fullpath/merge_requests/$1/notes" --field "body=@$2") | jq -r '.id // empty'
}

platform_head() {
  (cd "$REPO" && glab api "projects/:fullpath/merge_requests/$1") | jq -r '.sha // empty'
}

# inline komentar na dodatoj liniji: platform_post_inline <id> <fajl> <linija> <telo> <base_sha> <start_sha> <head_sha>
platform_post_inline() {
  (cd "$REPO" && glab api -X POST "projects/:fullpath/merge_requests/$1/discussions" \
    --field "body=@$4" -f "position[position_type]=text" \
    -f "position[base_sha]=$5" -f "position[start_sha]=$6" -f "position[head_sha]=$7" \
    -f "position[new_path]=$2" -f "position[old_path]=$2" -f "position[new_line]=$3") | jq -r '.id // empty'
}

platform_approve() {
  (cd "$REPO" && glab api -X POST "projects/:fullpath/merge_requests/$1/approve") | jq -r '.id // empty'
}
