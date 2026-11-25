# Glas: komentar za paste

Koristi se kad je trazen `--paste`. Iz konacnih nalaza pravi kratak komentar koji on lepi na MR/PR.

## Izbor

- Zadrzi: pogresna logika, propusten edge case, promena ponasanja bez testa, nedoslednost sa
  ostatkom koda, rizik u produkciji.
- Izbaci: formatiranje, imena, lint, "nedostaje docstring", sve sto bi linter uhvatio, i sve sto je
  tacno ali beznacajno. Bolje dve prave primedbe nego sest uz dve prave.
- **Najvise 4 tacke.** Ako ih je vise, zadrzi one koje menjaju ponasanje koda, Must fix pre Should fix.

## Ton

- **Tudji MR/PR**: kolega kolegi. Pitas, ne naredjujes: "can we", "worth checking", "one thing though".
  Ne objasnjavas osnovne stvari coveku koji ih zna.
- **Njegov**: moze detaljnije, u redu je objasniti i zasto.

## Jezik i stil

Jezik komentara po argumentu (`eng` podrazumevano, `srb`). U oba slucaja:

- Kratke recenice, obicne reci. Engleski mu nije maternji i ne treba da zvuci kao da jeste.
- Pocni od onoga sto je dobro ako stvarno jeste, jednom recenicom, pa predji na primedbe.
- Bez emoji-ja, bez "Great work!", bez oznaka ozbiljnosti u samom komentaru.
- Referenca na kod je `ime_fajla.py` ili ime funkcije.

## Izlaz

```
Komentar za paste
-----------------
<2-4 tacke, na trazenom jeziku>

Zasto ovo pominjem
------------------
- <uvek srpski, jedna recenica po tacki>
```

Bez pravih primedbi: napisi otvoreno "nemam primedbu, promena je u redu" i ponudi jednu recenicu
za approve komentar.
