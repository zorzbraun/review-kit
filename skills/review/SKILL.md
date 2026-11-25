---
name: review
description: "Review code changes in one pass on Opus and report verified findings as Must fix / Should fix / Advisory - his own local changes before push (teaching tone), a branch or commit, or someone else's merge request / pull request on GitLab or GitHub. With --paste it returns a short comment in his voice ready to paste, in English or Serbian. Runs the repo's own review-code skill next to it when the project profile enables it, and logs every finding for later scoring. Never posts anything. Use when he asks review, pregledaj izmene, pregledaj MR, pregledaj PR, napisi komentar za MR, review komentar, review this in my style, or invokes /review [cilj] [--paste srb|eng]."
argument-hint: "[MR/PR broj | URL | grana | commit] [--paste srb|eng] [--base <grana>] [--bez-motora]"
---

# Review

Jedan prolaz na Opus-u, sa proverom svakog nalaza. Za rizicne MR-ove postoji `/deep-review`.

```
/review                      tvoje lokalne izmene, i necommit-ovane (pre push-a)
/review 37349                MR ili PR po broju (platforma iz profila)
/review <URL>                MR ili PR po linku
/review moja-grana           grana ili commit
/review 37349 --paste srb    isto, ali izlaz je kratak komentar u tvom glasu (srb ili eng)
/review 37349 --bez-motora   samo kit, bez dodatnog motora iz profila
```

**Nikad ne postuje.** Komentar za paste on lepi sam.

## Korak 1 — pripremi cilj

Iz `$ARGUMENTS` izdvoji `--paste <jezik>` i `--bez-motora`; ostatak (cilj i `--base`) ide adapteru:

```bash
KIT=$(cd -P "${CLAUDE_SKILL_DIR}/../.." && pwd)
"$KIT/adapters/target.sh" <cilj i --base ako postoji>
```

Pokreni iz foldera repoa koji se review-uje (trenutni folder sesije, osim ako on kaze drugi; tada `--repo <putanja>`).
Ispis daje `OUT`, `KIND`, `FILES`, `LINES`, `WORKTREE`, `PROFILE_NAME` i komandu `CLEANUP`.
**Zapamti `CLEANUP` i pokreni je na kraju, i kad nesto pukne.**

Ako adapter vrati `GRESKA`, javi je jednom recenicom i stani.

Ako je `LINES` preko 3000, reci da je promena prevelika za jedan prolaz i predlozi `/deep-review` ili
review po delovima. Nastavi samo ako on to potvrdi.

## Korak 2 — odluci ton i motore

Procitaj `$OUT/context.env` i `$OUT/meta.json`.

**MODE:**
- `own` za `KIND=local` i `KIND=ref`.
- Za `KIND=pr`: `own` ako je `meta.author` njegov nalog (`glab api user` ili `gh api user`, polje
  `username`/`login`), inace `peer`.

**Motori:** `ENGINES` iz profila. Dodatni motor `repo-review-code` se pokrece ako:
- je u `ENGINES`, i nije zadat `--bez-motora`, i
- postoji `$WORKTREE/.claude/skills/review-code/SKILL.md`.

Ako je u profilu a fajl ne postoji, zapamti razlog za izvestaj ("dodatni motor nije pokrenut: <razlog>").

## Korak 3 — pusti agente paralelno

U **jednoj poruci**, oba `Agent` poziva, `model: opus`, u pozadini ako ih ima vise:

**A. Kit (`subagent_type: quick-reviewer`)**, prompt:

```
OUT=<OUT>
MODE=<own|peer>
Pravila: <KIT>/core/rules.md
Format nalaza: <KIT>/core/finding-schema.md
```

**B. Dodatni motor (`subagent_type: general-purpose`)**, samo ako je ukljucen, prompt:

```
Pokreni review po uputstvu iz <WORKTREE>/.claude/skills/review-code/SKILL.md i njegovim referencama
(citaj ih iz <WORKTREE>). Korak u kom uputstvo samo racuna diff preskoci: diff je vec spreman u
<OUT>/diff.patch, lista fajlova u <OUT>/name-status.txt, a kod za kontekst citaj iz <WORKTREE>.
Ne postuj nista, ne zovi nijedan skill sa --post, ne menjaj fajlove.
Kad zavrsis, prevedi svoje nalaze u JSON niz po formatu iz <KIT>/core/finding-schema.md
(ozbiljnost zadrzi kako je data; sta nema ozbiljnost je Advisory) i stavi ga u jedan ```json blok na kraju.
```

Iz svakog odgovora izvadi ```json blok i sacuvaj ga u `$OUT/findings/kit.json` i
`$OUT/findings/repo-review-code.json`. Ako blok fali ili nije ispravan JSON, taj izvor je
**nedostupan**, ne "bez nalaza", i tako ide u izvestaj.

## Korak 4 — spoji i proveri

Po `<KIT>/core/gate.md`:

1. Spoji izvore, ukloni duplikate, svakom nalazu dodaj `sources`.
2. Svaki Must fix i Should fix kandidat **proveri sam** u `WORKTREE`: otvori fajl na liniji, otvori
   celu ulaznu funkciju, proveri da raniji guard vec ne resava problem.
3. Impact gate za Must fix.
4. Odbaci nalaz koji ne mozes da potvrdis u kodu, i zapamti koliko si ih odbacio i zasto.

Konacnu listu sacuvaj u `$OUT/findings/final.json` (isti format, sa `sources`).

## Korak 5 — upisi u dnevnik

```bash
python3 "$KIT/scripts/log_findings.py" "$OUT" "$OUT/findings/final.json" quick
```

Dnevnik je u `LOG` iz profila, bez koda; `/review-log` ga kasnije ocenjuje.

## Korak 6 — javi

**Sa `--paste`:** izlaz po `<KIT>/core/voice.md`, iz `final.json`. Nista drugo.

**Bez `--paste`**, ovim redom:

```
## Review: <naslov> (<KIND> <ID>, profil <PROFILE_NAME>)

<2-3 recenice: sta promena radi i ukupna ocena: u redu / ima primedbi / ima blokera>

### Must fix
### Should fix
### Advisory
```

Svaki nalaz:

```
**<naslov>** — `fajl.py:42` (<izvori>)
Problem: ...
Zasto je bitno: ...
Okidac: ...            (samo za Must fix)
Predlog: <konkretan kod ili pristup>
```

Prazne sekcije izostavi. Na kraju jedna linija po izvoru: koliko nalaza je dao, koliko je preslo
proveru, i da li je neki izvor bio nedostupan ili nije pokrenut (sa razlogom).

Za `MODE=own` objasnjavaj kao junioru: obicne reci, zasto, primer. Za `peer` kratko.
Bez nalaza: "Nemam primedbu, promena je u redu." plus jedna recenica sta je dobro uradjeno.

## Korak 7 — pocisti

```bash
<CLEANUP komanda iz Koraka 1>
```

## Pravila

- **Nikad ne postuje** na GitLab/GitHub, ni ovaj skill ni bilo sta sto pozove. Nijedan skill sa `--post`.
- Ne prikazuj sirov izlaz agenata; on vidi samo spojene i proverene nalaze.
- Nikad `git add`, `git commit`, `git push`, i nijedna komanda iz `FORBIDDEN`.
- Razgovor na srpskom, programerski termini na engleskom, bez emoji-ja.
