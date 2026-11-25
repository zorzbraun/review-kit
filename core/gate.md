# Spajanje i ocena nalaza

Radi ga onaj ko spaja izvore (`/review` Korak 4, `/deep-review` Korak 4). Cilj: malo nalaza,
svaki proveren, i ozbiljnost koja znaci isto u svakom izvestaju.

## 1. Spoji

- Isti **uzrok** je jedan nalaz, i kad ga izvori opisuju razlicitim recima ili na susednim linijama.
  Zadrzi najjasniji opis, a u `sources` upisi sve izvore koji su ga nasli.
- Razliciti uzroci na istoj liniji ostaju odvojeni nalazi.
- Kad se dva izvora **ne slazu** (jedan kaze da poziv radi, drugi da puca), ne biraj po vecini:
  otvori kod i presudi sam, pa u `problem` napisi na cemu se presuda zasniva.

## 2. Proveri sam

Za svaki Must fix i Should fix kandidat:
1. otvori fajl na liniji i celu funkciju oko nje
2. proveri da raniji guard ili obrada vec ne resava problem
3. za nalaz o ugovoru sa spoljnim kodom, prati poziv kroz omotac repoa (`core/rules.md`, pravilo 2)

Vise izvora koji kazu isto **nije dokaz**; mozda su svi procitali isti diff na isti nacin.
Nalaz koji ne mozes da potvrdis u kodu odbaci i zapamti koliko si takvih odbacio i zasto.

**Izuzetak: neproveren ugovor se ne odbacuje.** Kad nalaz tvrdi da nov ili izmenjen poziv ne odgovara
spoljnom kodu (biblioteka, SDK, verzija API-ja, polje koje mozda ne postoji), a izvor tog koda nije
u repou, to sto ne mozes da ga potvrdis nije razlog za odbacivanje. Proveri ono sto jeste u repou
(da li je poziv nov, kako ga drugi pozivi koriste, sta se desi kad pukne, koja je verzija pinovana)
i zadrzi nalaz kao **Should fix** sa `contract unverified` u `why`, uz recenicu sta autor treba da
proveri. Odbaci ga samo ako kod u repou **pokazuje** da je ugovor ispravan (npr. isti poziv sa istim
argumentima vec radi na drugom mestu, i to sa istom verzijom).

## 3. Ozbiljnost

Samo tri reci:

| ozbiljnost | znacenje |
|---|---|
| **Must fix** | prolazi sva tri uslova ispod; ne sme u merge |
| **Should fix** | stvaran problem, ali neki uslov nije dokazan; ispraviti pre ili odmah posle merge-a |
| **Advisory** | citljivost, mala optimizacija, test koji bi bio lep; autor odlucuje |

**Must fix** samo ako vazi sve troje:
1. **okidac je dostizan:** postoji put iz produkcije (zahtev, job, webhook) do linije, sa konkretnim ulazom
2. **posledica je stvarna:** pad, pogresni ili izgubljeni podaci, novac, sigurnost, posao koji tiho ne radi
3. **nista ga ne hvata:** nijedan guard, retry ili obrada usput ne spasava situaciju

Ako uslov 1 ili 2 zavisi od podataka koje ne vidis (koliko prodavnica ima flag, da li se ruta koristi),
nalaz je Should fix sa napomenom "uticaj neizmeren" u `why`.

Ocenu rizika cele promene (Low/Medium/High) daje vlasnik pravila repoa ako postoji; kit je ne izmislja.

## 4. Manje je bolje

- Advisory najvise 5, najkorisniji prvi. Ukus i stil se ne prijavljuju.
- Nalaz koji samo ponavlja drugi nalaz drugim recima se spaja, ne dodaje.
- Ako nema nalaza, prazna lista je ispravan rezultat.
