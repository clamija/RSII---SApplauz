# FAZA 8: Flutter Mobile - Test Plan

## Test Scenarios

### 8.1 Uklanjanje Admin funkcionalnosti

**TEST 1: Admin korisnik vidi poruku**
- Login kao `admin.nps@sapplauz.ba` / `AdminNPS123!`
- **Očekivano**: Prikazuje se poruka "Za administraciju koristite Desktop aplikaciju"
- **Očekivano**: Nema navigation bar

**TEST 2: SuperAdmin korisnik vidi poruku**
- Login kao `superadmin@sapplauz.ba` / `SuperAdmin123!`
- **Očekivano**: Prikazuje se poruka "Za administraciju koristite Desktop aplikaciju"
- **Očekivano**: Nema navigation bar

### 8.2 Blagajnik - Filtering po instituciji

**TEST 3: Blagajnik vidi samo termine za svoju instituciju**
- Login kao `blagajnik.nps@sapplauz.ba` / `BlagajnikNPS123!`
- Otvori BlagajnikDashboard
- **Očekivano**: Prikazuju se samo termini za NPS instituciju

**TEST 4: QR Scanner validira samo karte za instituciju**
- Login kao `blagajnik.nps@sapplauz.ba` / `BlagajnikNPS123!`
- Otvori QR Scanner
- Skeniraj QR kod karte za NPS instituciju
- **Očekivano**: Karta se validira uspješno
- Skeniraj QR kod karte za drugu instituciju (npr. KT)
- **Očekivano**: Karta se ne validira (greška)

### 8.3 Korisnik - Poboljšanja

**TEST 5: ShowsListScreen prikazuje sve predstave**
- Login kao `user@sapplauz.ba` / `User123!`
- Otvori ShowsListScreen
- **Očekivano**: Prikazuju se predstave iz svih institucija

**TEST 6: ShowDetailsScreen prikazuje status indikatore**
- Login kao `user@sapplauz.ba` / `User123!`
- Otvori ShowDetailsScreen za bilo koju predstavu
- **Očekivano**: Termini imaju status indikatore (boje):
  - Crvena za "Rasprodano"
  - Plava za "Trenutno se izvodi"
  - Narandžasta za "Posljednja mjesta"
  - Zelena za "Dostupno"

**TEST 7: MyTicketsScreen prikazuje samo svoje karte**
- Login kao `user@sapplauz.ba` / `User123!`
- Otvori MyTicketsScreen
- **Očekivano**: Prikazuju se samo karte koje je korisnik kupio
- **Očekivano**: Svaka karta ima status (Nije skenirana, Skenirana, Nevažeća)

**TEST 8: CheckoutScreen - Real-time provjera dostupnosti**
- Login kao `user@sapplauz.ba` / `User123!`
- Otvori ShowDetailsScreen
- Odaberi termin sa dostupnim mjestima
- Otvori CheckoutScreen
- **Očekivano**: Prikazuje se real-time dostupnost
- Ako se dostupnost promijeni tokom checkout procesa:
  - **Očekivano**: Prikazuje se poruka "Neko je bio brži" ili "Dostupnost je promijenjena"

### 8.4 Recenziranje

**TEST 9: ReviewScreen - Disable ako nije ispunjen uslov**
- Login kao `user@sapplauz.ba` / `User123!`
- Otvori ShowDetailsScreen za predstavu gdje korisnik nema skeniranu kartu
- Klikni na ocjenu (link na ReviewScreen)
- **Očekivano**: Prikazuje se poruka "Možete ostaviti recenziju samo nakon što odgledate predstavu"
- **Očekivano**: "Ostavi recenziju" sekcija je disabled

**TEST 10: ReviewScreen - Enable ako je ispunjen uslov**
- Login kao `user@sapplauz.ba` / `User123!`
- Kupi kartu za predstavu
- Skeniraj kartu (kao Blagajnik)
- Sačekaj da termin završi (ili koristi termin koji je već završio)
- Otvori ReviewScreen za tu predstavu
- **Očekivano**: "Ostavi recenziju" sekcija je enabled
- **Očekivano**: Može se kreirati recenzija

**TEST 11: ReviewScreen - Ažuriranje postojeće recenzije**
- Login kao `user@sapplauz.ba` / `User123!`
- Otvori ReviewScreen za predstavu gdje već postoji recenzija
- **Očekivano**: Prikazuje se postojeća recenzija
- **Očekivano**: Može se ažurirati recenzija

### 8.5 Image Helper

**TEST 12: ImageHelper - Fallback logika**
- Provjeriti da se slike prikazuju ispravno u ShowsListScreen
- Provjeriti da se slike prikazuju ispravno u ShowDetailsScreen
- **Očekivano**: Ako Show nema sliku, koristi se Institution slika
- **Očekivano**: Ako ni Institution nema sliku, koristi se default slika

## Ručno testiranje

Za ručno testiranje, pokrenite Flutter aplikaciju:

```bash
cd mobile
flutter run
```

Zatim testirajte svaki scenario ručno.

## Napomene

- Backend automatski filtrira podatke po InstitutionId iz uloge korisnika
- QR Scanner automatski validira samo karte za instituciju blagajnika
- ReviewScreen provjerava da li korisnik ima skeniranu kartu i da li je termin završio
- ImageHelper koristi fallback logiku za slike
