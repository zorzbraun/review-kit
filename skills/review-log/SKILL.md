---
name: review-log
description: "Score the findings that /review and /deep-review logged - list open findings, suggest whether each was accepted, rejected or noise by checking whether the merge request later changed the flagged code, mark them after his confirmation, and show which sources, levels and severities actually produce useful findings. Use when he asks review log, oceni nalaze, koliko su review-ovi korisni, statistika review-a, which lens is worth it, or invokes /review-log [stats|list|mark]."
argument-hint: "[stats | list | mark <id> <prihvacen|odbijen|sum>] [--profil <ime>]"
---

# Dnevnik review nalaza

Svaki `/review` i `/deep-review` upisuje nalaze u dnevnik profila (bez koda). Ovde se oni ocenjuju, da
bi se videlo koji izvor (lens, kit, dodatni motor) zaista donosi korisne nalaze, a koji samo šum.

```bash
KIT=$(cd -P "${CLAUDE_SKILL_DIR}/../.." && pwd)
python3 "$KIT/scripts/review_log.py" list|mark|stats ...
```

Ocene: **prihvacen** (autor je ispravio ili se složio), **odbijen** (nalaz je bio pogrešan ili
autor s razlogom odbio), **sum** (tačno, ali nebitno, nije vredelo pominjati).

## Bez argumenta ili `list`

1. `review_log.py list` (uz `--profil` ako je dat). Ako nema otvorenih nalaza, reci to i ponudi `stats`.
2. **Predlozi ocene** za otvorene nalaze čiji je cilj MR/PR (`url` postoji), grupisano po review-u.
   Iz foldera tog repoa:
   ```bash
   "$KIT/adapters/target.sh" <target> --no-worktree      # daje novi HEAD_SHA i stanje
   git log --oneline <logovani head_sha>..<novi HEAD_SHA> -- <file>
   git diff <logovani head_sha> <novi HEAD_SHA> -- <file>
   ```
   pa `CLEANUP` iz ispisa. Pravila predloga:
   - linije oko prijavljene izmenjene posle review-a na način koji odgovara predlogu: **verovatno prihvacen**
   - MR/PR merge-ovan, a to mesto netaknuto: **verovatno odbijen ili sum** (pitaj koje)
   - MR/PR još otvoren i netaknut: ne predlaži, ostaje otvoren
   - za lokalne izmene i grane nema traga posle review-a: pitaj njega

   Ako repo nije dostupan iz ove sesije, preskoči predloge i samo prikaži listu.
3. Pokaži predloge kao tabelu (id, naslov, predlog, dokaz u jednoj rečenici) i pitaj koje da upiše.
   **Ništa se ne upisuje bez njegove potvrde.**
4. Za potvrđene: `review_log.py mark <id> <ocena> "<kratak razlog>"`.

## `mark <id> <ocena> [napomena]`

Upiši direktno, pa potvrdi jednom linijom.

## `stats`

`review_log.py stats` i ispod toga kratko tumačenje na srpskom, samo ono što brojevi stvarno kažu:

- koji izvor ima najviše prihvaćenih nalaza, a koji najviše šuma
- da li `deep` nalazi nešto što `quick` ne nalazi (vredi li četiri agenta umesto jednog)
- da li Must fix nalazi stvarno budu prihvaćeni (da li je impact gate prestrog ili preblag)

Ispod 20 ocenjenih nalaza reci otvoreno da je uzorak premali za zaključak.

## Pravila

- Dnevnik ne sadrži kod i ne sme ga ni dobiti.
- Ocena je njegova odluka; predlog je samo predlog.
- Razgovor na srpskom, bez emoji-ja.
