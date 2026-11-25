# Komentar koji deep-review kaci na MR/PR

Dva dela: **zbirni komentar** (`$OUT/comment.md`, pises ga ti) i **inline komentari** po linijama
(`post_gate.py` ih pravi iz `final.json`). Engleski, kolega kolegi, kratke recenice, bez emoji-ja.

## Oznake

| u final.json | u komentaru | znacenje za autora |
|---|---|---|
| Must fix | **Must fix** | ne ide u merge dok se ne popravi |
| Should fix | **Should fix** | popraviti u ovom MR-u ili odmah posle |
| Advisory, `pre_existing: true` | **Follow-up** | problem stariji od promene, moze poseban MR |
| Advisory | **Optional** | autor odlucuje |

## Zbirni komentar

```
Deep review at <sha8> (<code read, no tests run | tests run: ...>). <Jedna-dve recenice: da li
promena radi ono sto obecava, i koliko ima za popravku.>

**Must fix**
1. **<naslov>** (`fajl.py:42`, inline). <jedna recenica posledice>

**Should fix**
1. ...

**Follow-up** (fine as a separate MR)
1. ...

**Optional**
- ...

**What I checked**
- <pozivaoci, putanje, verzije, testovi koji bi pali bez fixa; konkretno, sa fajl:linija>

**Claims in the description**

| Claim | Holds? |
|---|---|
| <tvrdnja, skraceno> | Yes / No: <zasto> / Not verified |

**Not verified**
- <sta nije moglo da se proveri i zasto>
```

- Prazne sekcije izostavi. Ako nema nalaza: prva recenica kaze da je promena u redu, pa What I checked.
- Nalaz koji ide inline je u zbirnom jedna recenica sa `(file:line, inline)`. Nalaz iz `summary_only`
  (linija nije dodata u diffu, ili nalaz na nivou cele promene) dobija pun opis u zbirnom:
  problem, okidac, predlog.
- Ako testovi nisu pokrenuti, prva recenica sadrzi tacno `no tests run`.

## Drugi krug

Ako u `$(dirname "$LOG")/runs/` postoji raniji run za isti MR (`<ID>-*`), zbirni pocinje sa
`Round <n> at <sha8>`, pa tabela:

| Round <n-1> | Status |
|---|---|
| 1. <naslov ranijeg nalaza> | Fixed / Not fixed / Partly: <kako> |

Status utvrdi u kodu, ne iz odgovora autora. Novi nalazi idu ispod tabele u istim sekcijama.

## Inline komentar

```
**Should fix:** <naslov>

<problem>

Why it matters: <why>

Trigger: <trigger>

Suggestion: <fix>
```
