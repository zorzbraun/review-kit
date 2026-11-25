# review-kit

Prenosiv code review set za Claude Code. Radi sa GitLab-om, GitHub-om i lokalnim izmenama, i ne zna
ni za jednu firmu: sve sto je firmino (osnovna grana, test komanda, domenska pravila, dodatni review
motor) dolazi iz **profila** koji zivi u firminom repou.

## Instalacija

```bash
./install.sh
```

Firmin repo linkuje svoje profile u `~/.review-kit/profiles/`. Bez profila vazi `profiles/generic.yaml`.

## Skill-ovi

| Komanda | Kada | Agenti |
|---|---|---|
| `/review [cilj] [--paste srb\|eng]` | svakodnevni review, i tvoje izmene pre push-a | `quick-reviewer` (+ motor iz profila) |
| `/deep-review <cilj>` | rizicne promene | `deep-logic`, `deep-contracts`, `deep-evidence` |
| `/review-log` | ocenjivanje nalaza iz dnevnika | - |
| `/review-bench` | merenje recall-a na slucajevima sa poznatim bugom | `bench-judge` |

Pravila za sve agente su u `core/rules.md`, a spajanje i ozbiljnost u `core/gate.md`.

## Adapteri

| Skripta | Sta radi |
|---|---|
| `adapters/profile.sh [repo]` | nadje profil po `origin` URL-u, ispise ga kao `KLJUC=vrednost` |
| `adapters/target.sh [cilj]` | cilj u folder sa `diff.patch`, `meta.json`, `context.env` i worktree-om |
| `adapters/cleanup.sh <OUT>` | uklanja worktree (samo `rk-*`) i privremeni folder |

Cilj moze biti: nista (lokalne izmene, i necommit-ovane), broj MR-a ili PR-a (`123`, `!123`, `#123`),
URL MR-a ili PR-a, grana ili commit.

- Diff se racuna od commit-a od kog ga racuna i platforma (`diff_refs.base_sha` / `base.sha`), pa
  radi i za vec merge-ovan MR.
- GitHub ide kroz `gh` ako je instaliran, inace kroz javni API (samo javni repoi).
- U repou se menjaju samo `refs/review-kit/*` i dodaje se detached worktree.

## Profil

```yaml
name: moj-projekat
remote_match: github\.com[:/]firma/projekat(\.git)?$
platform: auto            # gitlab | github | auto
base_branch: auto         # auto = podrazumevana grana origin-a
worktree_dir: ~/.review-kit/worktrees
test_command:             # {files} se zamenjuje listom test fajlova
test_selector:
forbidden:                # komande koje review nikad ne sme da pokrene
rule_sources: CLAUDE.md, CONTRIBUTING.md
engines: kit              # kit, repo-review-code
log: ~/.review-kit/log/moj-projekat.jsonl
```
