# Format nalaza

Svaki izvor (kit agent ili dodatni motor) vraca nalaze kao JSON niz, u bloku ```json na kraju odgovora.

```json
[
  {
    "severity": "Must fix | Should fix | Advisory",
    "category": "bug | breaking-change | edge-case | security | performance | error-handling | concurrency | tests | docs | readability",
    "title": "kratak naslov, do 100 znakova, bez koda",
    "file": "putanja/u/repou.py",
    "line": 42,
    "problem": "sta ne valja, obicnim recima",
    "why": "sta pukne u produkciji",
    "trigger": "konkretan ulaz ili stanje koje stize do greske, ili null",
    "fix": "konkretna popravka ili pristup",
    "pre_existing": false,
    "confidence": "high | medium | low",
    "verified": true
  }
]
```

- `file` i `line` su obavezni osim za nalaz na nivou cele promene (`file: null`).
- Nema nalaza: prazan niz `[]`. Ne izmisljaj nalaz da bi izvestaj izgledao korisno.
- `verified` dodaje orkestrator (ne izvor) kad je nalaz sam otvorio u kodu i potvrdio; `/deep-review`
  ne kaci Must fix ni Should fix bez njega.
- Orkestrator posle spajanja dodaje `sources` (lista izvora) i konacnu `severity` posle impact gate-a.
