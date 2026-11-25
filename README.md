# review-kit

A portable code review set for Claude Code. It works with GitLab, GitHub and local changes, and it
knows nothing about any particular company: everything company-specific (base branch, test command,
domain rules, an extra review engine) comes from a **profile** that lives in the company's repo.

## Install

```bash
./install.sh
```

A company repo links its own profiles into `~/.review-kit/profiles/`. Without a profile,
`profiles/generic.yaml` applies.

## Skills

| Command | When | Agents |
|---|---|---|
| `/review [target] [--paste srb\|eng]` | everyday review, including your own changes before a push | `quick-reviewer` (+ engine from the profile) |
| `/deep-review <target>` | risky changes | `deep-logic`, `deep-contracts`, `deep-evidence` |
| `/review-log` | scoring findings from the log | - |
| `/review-bench` | measuring recall on cases with a known bug | `bench-judge` |

The rules for every agent are in `core/rules.md`; merging and severity are in `core/gate.md`.

## Adapters

| Script | What it does |
|---|---|
| `adapters/profile.sh [repo]` | finds the profile by `origin` URL and prints it as `KEY=value` |
| `adapters/target.sh [target]` | turns a target into a folder with `diff.patch`, `meta.json`, `context.env` and a worktree |
| `adapters/cleanup.sh <OUT>` | removes the worktree (only `rk-*`) and the temporary folder |

A target can be: nothing (local changes, including uncommitted ones), an MR or PR number (`123`,
`!123`, `#123`), an MR or PR URL, a branch or a commit.

- The diff is computed from the same commit the platform uses (`diff_refs.base_sha` / `base.sha`),
  so it also works for an MR that is already merged.
- GitHub goes through `gh` if it is installed, otherwise through the public API (public repos only).
- The only changes made in the repo are `refs/review-kit/*` and a detached worktree.

## Profile

```yaml
name: my-project
remote_match: github\.com[:/]company/project(\.git)?$
platform: auto            # gitlab | github | auto
base_branch: auto         # auto = the origin's default branch
worktree_dir: ~/.review-kit/worktrees
test_command:             # {files} is replaced with the list of test files
test_selector:
forbidden:                # commands the review must never run
rule_sources: CLAUDE.md, CONTRIBUTING.md
engines: kit              # kit, repo-review-code
log: ~/.review-kit/log/my-project.jsonl
```
