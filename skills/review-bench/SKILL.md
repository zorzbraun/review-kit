---
name: review-bench
description: "Measure how well /review, /deep-review and /six-lens catch real bugs - runs the chosen review levels on old changes whose bug is known from a later revert or fix, on a sealed copy of the code without git history, lets a strict judge agent decide hit or miss, and prints recall, findings per case and time per level. Expensive: up to a dozen Opus agents per case. Use when he asks benchmark, izmeri review, koliko review hvata, review-bench, or invokes /review-bench [fajl sa slucajevima] [--nivo quick|deep|six-lens|sve, zarezom] [--slucaj id,...]."
argument-hint: "[cases.json] [--nivo quick|deep|six-lens|sve, zarezom] [--slucaj id1,id2]"
---

# Benchmark review-a

Pita jedno pitanje: **da li review hvata bug koji znamo da je postojao?** Slucaj je stara promena
ciji je bug kasnije potvrdjen revertom ili popravkom. Review dobija samo tu promenu, na kopiji koda
bez git istorije, pa ne moze da "zaviri" u revert.

**Skupo:** po slucaju oko 3 agenta za quick (kit, motor, spajanje), 4 za deep, 7 za six-lens i
po jedan sudija za svaki nivo, svi Opus. Pre pokretanja reci koliko slucajeva i nivoa ide i trazi potvrdu.

**Limit od 20 istovremenih agenata** (ugnjezdeni se racunaju): pusti najvise 2 slucaja odjednom
ako je six-lens u igri, 3 ako nije, i sledeci slucaj tek kad se oslobodi mesto.
Ako verzija koda nema `.claude/skills/review-code/SKILL.md`, motor se za taj slucaj ne pokrece.

## Format slucajeva

JSON niz (format i primer u `<KIT>/bench/README.md`). Podrazumevani fajl je `bench` iz profila
trenutnog repoa; firmini slucajevi zive u firminom repou, nikad u kitu.

## Tok po slucaju

`KIT=$(cd -P "${CLAUDE_SKILL_DIR}/../.." && pwd)`. Za svaki izabrani slucaj, redom (ne paralelno,
da se kontekst ne pomesa):

1. **Pripremi i zapecati:**
   ```bash
   "$KIT/adapters/target.sh" <head_sha> --base <base_sha> --repo <repo iz slucaja ili trenutni>
   "$KIT/bench/seal.sh" "$OUT"
   mkdir -p "$OUT/findings"
   ```
   Zapamti `CLEANUP` i vreme pocetka. Posle `seal.sh` `WORKTREE` i `REPO` u `context.env` pokazuju na
   zapecacenu kopiju.

2. **Slepi orkestratori.** Ti znas bug, pa **ne smes** da pises brief, hintove ni da spajas nalaze:
   tvoje znanje bi navelo review na odgovor. Sve to rade agenti koji bug ne znaju. Jedna poruka,
   svi `run_in_background: true`, `model: opus`:
   - **kit** (`quick-reviewer`): `OUT`, `MODE=peer`, putanje do `core/rules.md` i
     `core/finding-schema.md`, i "upisi svoj JSON niz u `$OUT/findings/kit.json`".
   - **deep orkestrator** (`general-purpose`, ako je `deep` trazen): neka uradi Korake 2, 3 i 4 iz
     `deep-review/SKILL.md` na `OUT`, bez `discussions.sh`, bez motora, dnevnika, izvestaja,
     postovanja i cleanup-a, i upise konacnu listu u `$OUT/final-deep.json`. Ako mu alat Agent
     nije dostupan, mora da stane.
   - **dodatni motor** (`general-purpose`, ako ga profil ukljucuje): prompt iz `/review` Koraka 3B,
     uz "upisi JSON niz u `$OUT/findings/repo-review-code.json`". Isti izlaz koriste quick i six-lens (deep ga ne koristi).
   - **six-lens orkestrator** (`general-purpose`, ako je six-lens trazen): neka uradi Korake 2, 2a, 3
     i 5 iz `~/.claude/skills/six-lens/SKILL.md` (spoljni nivo, ako je instaliran) na `OUT`, bez `discussions.sh`, bez dodatnog motora, bez mutanata,
     dnevnika, postovanja i cleanup-a, i upise spojene lens nalaze u `$OUT/findings/six-lens-only.json`.
     Ako mu alat Agent nije dostupan, mora da stane, ne da glumi lensove.

   U svaki prompt (i u prompt lensova) dodaj: *"Benchmark: ne pokreci nijednu git komandu i ne
   citaj nista van putanja koje si dobio."*

3. **Spajanje, takodje slepo.**
   - **quick**: kad stignu kit i motor, `general-purpose` agent radi Korak 4 iz `review/SKILL.md`
     nad ta dva fajla i upisuje `$OUT/final-quick.json`.
   - **six-lens**: `six-lens-only.json` plus nalazi motora koji nisu duplikati (isti fajl, linija
     +-3, ista kategorija) daju `$OUT/final-six-lens.json`. Ovo je mehanicko spajanje, bez tvog suda.

   - **deep**: `final-deep.json` je vec spojen u orkestratoru; nista se ne dodaje.

   **Vreme** je kriticna putanja agenata iz njihovih `duration_ms`, ne sat na zidu:
   quick = max(kit, motor) + spajanje; six-lens = six-lens orkestrator (motor radi paralelno);
   deep = deep orkestrator.
   Ako orkestrator ocigledno visi (mnogo duze od ostalih), upisi `null` i reci zasto.

4. **Sudija** po nivou (`subagent_type: bench-judge`, `model: opus`), prompt:
   ```
   Bug: <bug iz slucaja>
   Fajlovi gde zivi: <expected_files>
   SEALED: <WORKTREE>
   Nalazi: <ceo sadrzaj final-<nivo>.json>
   ```
   Njegov JSON sacuvaj u `$OUT/judge-<nivo>.json`. **Sudiji nikad ne daj sopstveno misljenje.**

5. **Upisi** (sekunde iz Koraka 3):
   ```bash
   python3 "$KIT/bench/results.py" add <results.jsonl> <id> <nivo> "$OUT/final-<nivo>.json" "$OUT/judge-<nivo>.json" <sekunde>
   ```
   `results.jsonl` je `results.jsonl` pored fajla sa slucajevima.

6. `CLEANUP`, i kad slucaj pukne. Slucaj koji pukne upisi kao gresku u odgovoru, ne kao promasaj.

## Na kraju

```bash
python3 "$KIT/bench/results.py" table <results.jsonl>
```

Pokazi tabelu i kratko protumaci na srpskom: recall po nivou, da li dubok nivo hvata nesto sto quick
ne hvata, koji izvor nalazi pogotke, i koliko nalaza po slucaju ide uz pogodak (da li je recall
kupljen bukom). Ispod 10 slucajeva reci da je uzorak mali. Rezultati su vezani za verziju kita
(`run` polje), pa posle izmene pravila pokreni ponovo i uporedi.

## Pravila

- Nikad ne pokazuj reviewer-u bug, revert, popravku ni opis slucaja.
- Nista se ne postuje i ne upisuje u dnevnik nalaza.
- Razgovor na srpskom, bez emoji-ja.
