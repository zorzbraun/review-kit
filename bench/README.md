# Benchmark

`/review-bench` meri da li `/review` i `/deep-review` hvataju bug koji je stvarno postojao.

## Slucaj

Jedan objekat u JSON nizu. Fajl sa slucajevima zivi u repou firme ili projekta (putanja je `bench`
u profilu), nikad u kitu, jer opisuje tudji kod.

```json
{
  "id": "proj-1234",
  "repo": "~/code/projekat",
  "head_sha": "<40 hex: poslednji commit bagovite promene>",
  "base_sha": "<40 hex: commit od kog promena krece>",
  "bug": "1-3 recenice: konkretan uzrok i posledica, iz dokaza",
  "expected_files": ["putanja/gde/bug/zivi.py"],
  "evidence": "revert MR/PR, diskusija, popravka",
  "detectability": "high | medium | low"
}
```

- `head_sha` i `base_sha`: za MR/PR to su `sha` i `diff_refs.base_sha` (GitLab) ili `head.sha` i `base.sha` (GitHub).
- Dobar slucaj: bug se vidi citanjem promene i okolnog koda. Los slucaj: infrastruktura, memorija,
  verzije biblioteka, odluke o proizvodu, flaky testovi.

## Izolacija

`seal.sh` kopira kod bez `.git` i brise worktree, pa reviewer ne moze kroz istoriju da vidi revert
ili popravku. Sudija (`agents/bench-judge.md`) jedini zna bug.

## Rezultati

`results.jsonl` pored fajla sa slucajevima; svaki red nosi `run` = datum + verziju kita, pa se
merenja posle izmene pravila porede sa starim. `bench/results.py table` pravi tabelu.
