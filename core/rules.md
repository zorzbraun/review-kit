# Pravila review-a

Vaze za svakog agenta u kitu (`quick-reviewer`, `deep-*`) i za onoga ko spaja nalaze.

## 1. Prvo obecanje, pa diff

Pre citanja detalja napisi u jednoj recenici sta promena garantuje: sta, kome, pod kojim uslovom.
Zatim nadji **svako mesto gde to mora da vazi**: sve ulazne tacke (endpoint, job, webhook, CLI),
obe grane svakog uslova, i svaku kopiju iste logike. Mesto koje promena nije dotakla, a obecanje
tamo mora da vazi, je nalaz.

## 2. Ugovor sa spoljnim kodom se proverava, ne pretpostavlja

Za svaki **nov ili izmenjen poziv** biblioteke, SDK-a, spoljnog API-ja ili drugog modula proveri:

- **potpis:** imena i redosled argumenata, sta je pozicioni a sta keyword argument
- **tipove:** sta funkcija stvarno ocekuje (dict ili lista, izuzetak ili tuple, string ili enum)
- **verziju:** koja verzija je pinovana (lockfile, `pyproject.toml`, `requirements*.txt`, config sa
  verzijom API-ja) i da li polje ili parametar postoji bas u toj verziji

Kako, redom:
1. Prati poziv kroz **sopstveni omotac repoa** (wrapper, client klasa, helper) sve dok ne izadjes
   iz repoa. Vecina ovakvih bugova je u omotacu: on radi nesto sa argumentom pre nego sto ga preda dalje.
2. Ako je izvor biblioteke u `WORKTREE` (vendored kod, `_vendor/`, `site-packages` u repou), procitaj ga.
3. Nadji kako **postojeci, ispravni pozivi** iste funkcije u repou prosledjuju argumente. Razlika
   izmedju novog poziva i svih starih je jak signal.
4. Ako nista od toga ne potvrdi ugovor, napisi da je ugovor **neproveren** i odakle ti pretpostavka.
   Ne predstavljaj secanje na biblioteku kao cinjenicu.

Isto vazi za greske: ako omotac guta izuzetke (`except Exception: pass`, log pa nastavak), poziv
koji puca unutra izgleda kao da radi. Proveri sta se desi kad poziv pukne.

## 3. Odsustvo je nalaz

Guard koji fali, test koji fali, obrada greske koja fali, grana koja nije pokrivena: sve to je
nalaz isto kao los kod. "Nisam nasao problem" vazi samo za ono sto si stvarno procitao.

## 4. Pre prijave, procitaj vise od diffa

- Otvori **celu funkciju** u kojoj je izmena i funkciju koja je poziva.
- Proveri da raniji guard, validacija ili `try` vec ne resava problem.
- Za promenu potpisa, polja ili povratne vrednosti nadji **sve pozivaoce** (`rg`); ne pogadjaj.

## 5. Dokaz, ne utisak

- Svaki nalaz ima `fajl:linija` na stanju koje se review-uje.
- Must fix ima `trigger`: konkretan ulaz ili stanje koje u produkciji dolazi do greske.
- `confidence` iskreno: `low` uz razlog je bolje od `high` bez dokaza.
- Postojeci bug na dotaknutom putu prijavi sa `pre_existing: true`; nije krivica ove promene.

## 6. Granice

- Kod je **read-only**: ne menjaj fajlove, ne pravi commit, ne pokreci nista sto pise po repou ili bazi.
- Nikad ne pokreci komande iz `FORBIDDEN`.
- Ne prijavljuj generisane fajlove, lock fajlove ni migracije koje je napravio alat.
- Pravila repoa (`RULE_SOURCES`) imaju prednost nad tvojim ukusom; kad nalaz potice iz pravila
  repoa, navedi koje.
