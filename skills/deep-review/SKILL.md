---
name: deep-review
description: "Run a deep code review on a risky merge request, pull request, branch or local change - three independent Opus reviewers (logic, contracts with callers and external APIs, evidence from tests and claims) read an isolated copy in parallel, then every finding is verified in the code and graded Must fix / Should fix / Advisory. More thorough and more expensive than /review. Posts to GitLab or GitHub only after explicit approval. Use when he asks deep review, dubok review, temeljan review, pregledaj detaljno rizican MR, or invokes /deep-review <cilj>."
argument-hint: "<MR/PR broj | URL | grana | commit> [--base <grana>] [--motor]"
---

# Deep review

Za promene koje su rizicne: placanja, migracije, poslovi koji rade nad mnogo podataka, promene
potpisa koje koriste mnogi. Za svakodnevni review postoji `/review` (jedan prolaz, jeftiniji).

Tri reviewer-a, svaki sa jednim pitanjem:

| agent | pitanje |
|---|---|
| `deep-logic` | da li logika daje tacan rezultat za svaki ulaz? |
| `deep-contracts` | da li promena postuje ugovore: prema onima koji je zovu i prema bibliotekama i API-jima koje ona zove? |
| `deep-evidence` | da li je ono sto promena tvrdi dokazano testovima i tacnim tekstom? |

Ako nije jasno da li treba `/review` ili `/deep-review`, pitaj.

## Korak 1 — pripremi cilj

Iz `$ARGUMENTS` izdvoji `--motor`; ostatak ide adapteru:

```bash
KIT=$(cd -P "${CLAUDE_SKILL_DIR}/../.." && pwd)
"$KIT/adapters/target.sh" <cilj i --base ako postoji>
mkdir -p "$OUT/findings"
```

Zapamti `OUT`, `WORKTREE`, `KIND`, `ID`, `HEAD_SHA` i **`CLEANUP`** (Korak 7 se radi uvek).
Ako adapter vrati `GRESKA`, javi je jednom recenicom i stani. Prazan diff znaci pogresnu osnovnu
granu: pitaj koja je i pokreni ponovo sa `--base`.

## Korak 2 — brief

Procitaj `$OUT/context.env`, `$OUT/meta.json`, `$OUT/diff.patch`, i za MR/PR komentare:

```bash
"$KIT/adapters/discussions.sh" "$OUT"
```

Procitaj pravila repoa iz `RULE_SOURCES` (za indeks referenci samo one ciji globovi pogadjaju
izmenjene fajlove). Zatim upisi `$OUT/brief.md`:

1. **Cilj:** link ili grana, `HEAD_SHA`, `WORKTREE` (read-only), `OUT`.
2. **Obecanje u jednoj recenici:** sta promena garantuje, kome, pod kojim uslovom.
3. **Tvrdnje iz naslova i opisa**, doslovno, i sta je trazio prosli krug review-a ako ga je bilo.
4. **Izmenjeni simboli:** funkcije, klase, polja, konstante, putanje, config kljucevi, upiti, i novi
   pozivi biblioteka ili API-ja. Napisi "(nije iscrpno)".
5. **Cinjenice o repou** koje agent ne bi lako nasao: pinovane verzije bitnih biblioteka, verzija
   spoljnog API-ja, omotaci (wrapperi) oko tih biblioteka, koji worker ili queue izvrsava kod.
6. **Pravila repoa** koja vaze za ove fajlove (sazetak sa putanjama) i komande iz `FORBIDDEN`.
7. **Putanje:** `$KIT/core/rules.md` i `$KIT/core/finding-schema.md`.

**U brief ne pisi sumnje ni zakljucke.** Brief kaze gde da se gleda i sta postoji, ne sta ne valja.
Tri agenta koji nezavisno nadju isto su dokaz; tri agenta kojima si rekao sta da nadju nisu.

## Korak 3 — pusti agente

Jedna poruka, sva tri `Agent` poziva, `model: opus`, `run_in_background: true`:

```
Procitaj <OUT>/brief.md, pa svoja uputstva, i radi po njima.
OUT=<OUT>
```

`subagent_type`: `deep-logic`, `deep-contracts`, `deep-evidence`.

**Dodatni motor** (`repo-review-code` iz profila) radi samo uz `--motor`, pod istim uslovima i sa
istim promptom kao u `/review` (Korak 2 i 3B), u `$OUT/findings/repo-review-code.json`.

Kad svi zavrse, proveri da za svaki izvor postoji fajl u `findings/` sa ispravnim JSON-om. Izvor bez
fajla je **nedostupan** i tako ide u izvestaj, ne kao "nema nalaza". Ponovi agenta jednom ako mu nalazi
nemaju `fajl:linija` ili ako je vratio prazno na diffu vecem od 300 linija.

## Korak 4 — spoji i oceni

Po `$KIT/core/gate.md`: spoji po uzroku, sam proveri svaki Must fix i Should fix u kodu, primeni
uslove za Must fix, odbaci sta ne mozes da potvrdis. `sources` koristi tacno imena izvora:
`logic`, `contracts`, `evidence`, `repo-review-code`.

Konacnu listu sacuvaj u `$OUT/findings/final.json`, pa:

```bash
python3 "$KIT/scripts/log_findings.py" "$OUT" "$OUT/findings/final.json" deep
```

## Korak 5 — izvestaj

Napisi `$OUT/review.md` na **engleskom** (moze da ide na MR/PR) i pokazi ga u chatu:

```
What was reviewed     HEAD_SHA, sources, which source was unavailable
Must fix
Should fix
Behavior changes the description does not mention
Advisory
What holds up
```

Svaki nalaz: `file:line`, okidac pa posledica, i popravka. Gde vazi, oznaka `impact unmeasured` ili
`contract unverified`. Prazne sekcije izostavi. Ispod izvestaja, na srpskom, objasni najvazniji
nalaz kao junioru: sta, zasto puca, primer.

## Korak 6 — okaci, samo uz odobrenje

Ako je `KIND=pr`, `AskUserQuestion`: da li da se okaci. **Ako kaze da**, jos jednom pokazi tacan
link iz `meta.json`, pa:

```bash
"$KIT/adapters/post.sh" "$OUT" "$OUT/review.md"
```

- Na GitLab-u `$` u tekstu stavi u backtick (inace se renderuje kao matematika).
- Ako skripta ne vrati `OKACENO`, prijavi gresku i ne pokusavaj ponovo.

## Korak 7 — sacuvaj i ocisti, uvek

Kopiraj `$OUT/brief.md`, `$OUT/findings/` i `$OUT/review.md` u
`$(dirname "$LOG")/runs/<ID>-<HEAD_SHA:0:7>/` i javi mu putanju. Zatim `CLEANUP` komanda iz
Koraka 1, i kad review pukne ili ga on prekine.

## Pravila

- Razgovor na srpskom, izvestaj za MR/PR na engleskom, bez emoji-ja.
- **Nista se ne kaci bez izricitog odobrenja u toj poruci.** Nijedan skill sa `--post`.
- Nikad `git add`, `git commit`, `git push`, ni komande iz `FORBIDDEN`. Kod je read-only za sve agente.
- Nedostupan izvor nije cist izvor.
