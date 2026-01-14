# FAZA 3: Backend - Real-time provjera dostupnosti i checkout sigurnost - Testovi

## Preduvjeti

1. **API mora biti pokrenut** na `http://localhost:5169`
2. **Baza podataka** mora imati:
   - Test korisnike: `user@sapplauz.ba` / `User123!` i `user2@sapplauz.ba` / `User123!`
   - Najmanje jednu performancu sa dostupnim mjestima (`AvailableSeats > 0`)
3. **PowerShell** (za automatsko testiranje)

## Načini testiranja

### 1. Automatsko testiranje (PowerShell skripta)

```powershell
# Navigate to tests directory
cd backend/SApplauz.API/tests

# Run test script
.\Test-Faza3.ps1
```

**Rezultati:**
- Testovi se automatski izvršavaju
- Rezultati se prikazuju u konzoli
- Rezultati se eksportuju u JSON fajl: `test-results-faza3-YYYYMMDD-HHMMSS.json`

### 2. Ručno testiranje (HTTP fajl)

Koristite `.http` fajlove u Visual Studio Code sa REST Client ekstenzijom ili Postman:

1. Otvorite `faza3_checkout_security.http`
2. Postavite `@tokenUser1` i `@tokenUser2` varijable (login kao User 1 i User 2)
3. Postavite `@performanceId` i `@institutionId` sa realnim ID-jem iz baze
4. Pokrenite testove sekvencijalno

### 3. API Test kroz Postman/Insomnia

Importajte HTTP zahtjeve iz `faza3_checkout_security.http` fajla.

## Test Scenariji

### ✅ TEST 1: Quantity Validation
**Cilj:** Provjeriti da se odbija kupovina više karata nego što ima dostupno.

**Koraci:**
1. Pokušaj kreirati Order sa `quantity = 10000` kada ima samo npr. 50 dostupno
2. Očekivano: `400 Bad Request` sa porukom "Neko je bio brži!..."

**Status:** ✅ Testirano

---

### ✅ TEST 2: Sold Out Scenario
**Cilj:** Provjeriti da se odbija kupovina kada `AvailableSeats == 0`.

**Koraci:**
1. Postavite `AvailableSeats = 0` za performance (ručno u bazi)
2. Pokušaj kreirati Order
3. Očekivano: `400 Bad Request` sa porukom "Termin je rasprodan..."

**Status:** ✅ Testirano

---

### ⚠️ TEST 3: Race Condition (2 korisnika istovremeno)
**Cilj:** Provjeriti da optimistic locking radi kada 2 korisnika pokušaju kupiti zadnje karte.

**Koraci:**
1. Postavite `AvailableSeats = 2` za performance
2. **ISTOVREMENO** pokrenite 2 zahtjeva:
   - User 1: `quantity = 2`
   - User 2: `quantity = 1`
3. Očekivano: Jedan uspije, drugi dobija `400 Bad Request`

**Napomena:** Zahtijeva istovremeno pokretanje 2 zahtjeva (2 browser taba, 2 Postman instance, ili concurrent HTTP pozivi).

**Status:** ⚠️ Zahtijeva ručno testiranje ili concurrent HTTP klijent

---

### ⚠️ TEST 4: Ticket Generation
**Cilj:** Provjeriti da se generiše tačan broj karata sa jedinstvenim QR kodovima.

**Koraci:**
1. Kreiraj Order sa `quantity = 3`
2. Plati Order (simuliraj Stripe payment)
3. Provjeri da se generisalo 3 tickets sa jedinstvenim QR kodovima

**Napomena:** Zahtijeva validan Stripe payment intent (ili simulaciju plaćanja).

**Status:** ⚠️ Zahtijeva Stripe integraciju ili mock plaćanje

---

### ✅ TEST 5: Transaction Rollback
**Cilj:** Provjeriti da se rollback dešava u slučaju greške.

**Testovi:**
- Invalid Performance ID: `400/404 Bad Request`, Order se NE kreira
- Invalid Quantity (0): `400 Bad Request`, Order se NE kreira
- Negative Quantity: `400 Bad Request`, Order se NE kreira

**Status:** ✅ Testirano

---

### ⚠️ TEST 6: Payment Processing Race Condition
**Cilj:** Provjeriti da se rollback dešava ako mjesta nestanu između plaćanja i finalizacije.

**Koraci:**
1. Kreiraj Order sa `quantity = 5`
2. **ISTOVREMENO**: Drugi korisnik kupi 3 karte
3. Pokušaj platiti Order
4. Očekivano: Rollback, `Payment.Status = Failed`, `Order.Status = Pending`

**Napomena:** Zahtijeva validan Stripe payment intent i concurrent testiranje.

**Status:** ⚠️ Zahtijeva Stripe integraciju i concurrent testiranje

---

### ⚠️ TEST 7: AvailableSeats Update
**Cilj:** Provjeriti da se `AvailableSeats` smanjuje nakon plaćanja.

**Koraci:**
1. Provjeri `AvailableSeats` PRIJE plaćanja
2. Plati Order
3. Provjeri `AvailableSeats` NAKON plaćanja
4. Očekivano: Smanjen za tačno kupljenu količinu

**Napomena:** Zahtijeva validan Stripe payment intent.

**Status:** ⚠️ Zahtijeva Stripe integraciju

## Rezultati testiranja

Rezultati se automatski eksportuju u JSON fajl kada se pokrene PowerShell skripta.

Za ručno testiranje, dokumentujte rezultate u `TEST_RESULTS_FAZA3.md`.

## Napomene

1. **Stripe Payment Tests:** Testovi koji uključuju plaćanje (`TEST 4`, `TEST 6`, `TEST 7`) zahtijevaju:
   - Validan Stripe test API key
   - Simulaciju Stripe payment intent-a
   - Ili mock Stripe servis za development testiranje

2. **Race Condition Tests:** Testovi koji zahtijevaju istovremene zahtjeve (`TEST 3`, `TEST 6`) mogu se testirati:
   - Ručno sa 2 browser taba / Postman instance
   - Programski sa concurrent HTTP klijentima (npr. `Invoke-WebRequest` sa `-Parallel`)

3. **Database Setup:** Prije testiranja, provjerite da baza ima:
   - Test korisnike
   - Performances sa dostupnim mjestima
   - Institucije povezane sa performances

## Sljedeći koraci

- [ ] Implementirati mock Stripe servis za development testiranje
- [ ] Kreirati concurrent HTTP test klijent za race condition testove
- [ ] Dodati unit testove za `OrderService` metode
- [ ] Integrirati testove u CI/CD pipeline

