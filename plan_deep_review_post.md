# Deep review sam kaci komentar, posle provere

## Odluka

Opcija B: kad provera pre kacenja prodje, deep-review sam kaci zbirni komentar i inline komentare po
linijama. Approve nikad sam, uvek pita. Za MR/PR koji nije prosao proveru nista se ne kaci.

## Format (po uzoru na six-lens komentare kolega)

- **Zbirni komentar:** jedna recenica ocene sa SHA i nacinom provere ("code read, no tests run"), pa
  sekcije Must fix, Should fix, Follow-up (moze poseban MR), Optional, What I checked, Claims in the
  description (tabela drzi/ne drzi), Not verified. Nalazi su kratki, sa linkom na inline komentar.
- **Inline komentar** po nalazu na liniji iz diffa: oznaka, problem, okidac, predlog.
- **Drugi krug:** ako postoji prethodni run za isti MR, tabela "Round 1 | Status".

## Provera pre kacenja (`scripts/post_gate.py`, deterministicka)

1. Svi ocekivani izvori imaju ispravan JSON.
2. Svaki Must fix i Should fix ima `verified: true` (orkestrator ga je otvorio u kodu).
3. Nalazi sa `confidence: low` ne idu u komentar.
4. `checks.json` postoji: tvrdnje iz opisa sa presudom, `tests_run`, lista `not_verified`.
5. Ako testovi nisu pokrenuti, zbirni komentar to kaze.
6. Head MR-a uzivo je isti kao pregledani `HEAD_SHA`.
7. Nalaz ide inline samo ako je linija dodata u diffu; ostali idu samo u zbirni komentar.

Izlaz: `post-plan.json` (inline lista sa telom, summary_only lista) i PROLAZI / NE PROLAZI sa razlozima.

## Izmene

- `core/post-format.md` (nov): format zbirnog i inline komentara, mapiranje ozbiljnosti.
- `scripts/post_gate.py` (nov) i `tests/test_post_gate.py` (nov).
- `adapters/lib/gitlab.sh`, `github.sh`: `start_sha` u meta, `platform_head`, `platform_post_inline`, `platform_approve`.
- `adapters/post.sh`: provera head-a uzivo, `--inline <post-plan.json>`, neuspeli inline idu u zbirni.
- `adapters/approve.sh` (nov): approve, samo posle izricitog "da".
- `skills/deep-review/SKILL.md`: Korak 4 dodaje `verified`, Korak 5 pravi `checks.json` i `comment.md`,
  Korak 6 provera pa kacenje, pa pitanje za approve. Opis i pravila azurirani.
- `core/finding-schema.md`: polje `verified`.

## Verifikacija

- `python3 -m unittest discover tests`
- `bash -n` na izmenjenim skriptama
- Suvi prolaz gate-a na sacuvanom runu `37780-83ecaef` (bez kacenja).
