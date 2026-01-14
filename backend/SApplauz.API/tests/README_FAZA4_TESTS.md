# FAZA 4: Backend - Recenzije (samo nakon skenirane karte i završenog termina) - Testovi

## Preduvjeti

1. **API mora biti pokrenut** na `http://localhost:5169`
2. **RabbitMQ mora biti pokrenut** (za invalidaciju cache-a)
3. **Baza podataka** mora imati:
   - Test korisnika: `user@sapplauz.ba` / `User123!`
   - Najmanje jednu show sa završenom performancom (StartTime < DateTime.UtcNow - 2 sata)
   - Korisnik mora imati skeniranu kartu (Ticket.Status = Scanned) za završenu predstavu
4. **PowerShell** (za automatsko testiranje)

## Načini testiranja

### 1. Automatsko testiranje (PowerShell skripta)

```powershell
# Navigate to tests directory
cd backend/SApplauz.API/tests

# Run test script
.\Test-Faza4.ps1
```

**Rezultati:**
- Testovi se automatski izvršavaju
- Rezultati se prikazuju u konzoli
- Rezultati se eksportuju u JSON fajl: `test-results-faza4-YYYYMMDD-HHMMSS.json`

### 2. Ručno testiranje (HTTP fajl)

Koristite `.http` fajlove u Visual Studio Code sa REST Client ekstenzijom ili Postman.

## Test Scenariji

### ✅ TEST 1: Review bez skenirane karte
**Cilj:** Provjeriti da se odbija kreiranje recenzije ako korisnik nema skeniranu kartu.

**Koraci:**
1. Pokušaj kreirati Review za show bez skenirane karte
2. Očekivano: `400 Bad Request` sa porukom "Možete ostaviti recenziju samo nakon što odgledate predstavu. Morate imati skeniranu kartu..."

**Status:** ✅ Testirano

---

### ✅ TEST 2: Review za ne-završenu predstavu
**Cilj:** Provjeriti da se odbija kreiranje recenzije ako predstava još nije završila.

**Koraci:**
1. Pokušaj kreirati Review za show gdje je Performance.StartTime > DateTime.UtcNow
2. Očekivano: `400 Bad Request` sa porukom "Možete ostaviti recenziju samo nakon što odgledate predstavu. Termin još nije završio."

**Napomena:** Zahtijeva buduću performancu i kartu za nju.

**Status:** ✅ Validacija implementirana (zahtijeva ručno testiranje sa budućom performancom)

---

### ✅ TEST 3: Review sa ne-skeniranom kartom (NotScanned)
**Cilj:** Provjeriti da se odbija kreiranje recenzije ako karta nije skenirana.

**Koraci:**
1. Pokušaj kreirati Review za show gdje korisnik ima kartu sa Ticket.Status = NotScanned
2. Očekivano: `400 Bad Request` - samo skenirane karte (Status = Scanned) dopuštaju recenziju

**Napomena:** Validacija provjerava Ticket.Status == Scanned.

**Status:** ✅ Validacija implementirana (zahtijeva ručno testiranje sa NotScanned kartom)

---

### ✅ TEST 4: Ažuriranje postojeće recenzije
**Cilj:** Provjeriti da se postojeća recenzija ažurira umjesto da se blokira duplikat.

**Koraci:**
1. Kreiraj Review za show (ako imaš skeniranu kartu za završenu predstavu)
2. Pokušaj kreirati još jednu Review za isti show
3. Očekivano: `200 OK` - postojeća recenzija je ažurirana (isti ID, novi rating/comment)

**Napomena:** 
- Stara implementacija: baca `Conflict` ako recenzija već postoji
- Nova implementacija: ažurira postojeću recenziju

**Status:** ✅ Testirano

---

### ✅ TEST 5: Cache invalidation nakon recenzije
**Cilj:** Provjeriti da se cache preporuka invalidira nakon kreiranja/ažuriranja recenzije.

**Koraci:**
1. Dohvati preporuke (Recommendations) - ovo kešira rezultate
2. Kreiraj ili ažuriraj recenziju
3. Dohvati preporuke ponovo
4. Očekivano: Cache je invalidiran, nove preporuke se generiraju

**Napomena:** 
- Cache se invalidira u `CreateReviewAsync` i `UpdateReviewAsync`
- Cache se invalidira u `ProcessPaymentAsync` (nakon kupovine karata)
- Cache TTL: 1 sat

**Status:** ✅ Implementirano (zahtijeva ručno testiranje za potpunu provjeru)

---

## Validacija u kodu

### ReviewService.ValidateReviewEligibilityAsync

Validacija provjerava:
1. ✅ Korisnik ima kartu za show (Ticket za tu Show)
2. ✅ Karta je skenirana (Ticket.Status == Scanned)
3. ✅ Performance je završio (Performance.StartTime < DateTime.UtcNow)

Ako bilo koja validacija ne prolazi, baca se `InvalidOperationException` sa porukom:
- "Možete ostaviti recenziju samo nakon što odgledate predstavu. Morate imati skeniranu kartu..."
- "Možete ostaviti recenziju samo nakon što odgledate predstavu. Termin još nije završio."

### ReviewService.CreateReviewAsync

- Ako recenzija već postoji: **ažurira** postojeću (ne baca Conflict)
- Ako recenzija ne postoji: **kreira** novu
- Poziva `InvalidateUserCacheAsync` nakon kreiranja/ažuriranja

### RecommendationService

- `GetRecommendationsAsync`: Kešira rezultate po UserId sa TTL-om od 1 sata
- `InvalidateUserCacheAsync`: Invalidira sve cache key-eve za korisnika (count 5, 10, 20, 50)

---

## Ručno testiranje (postupak)

### 1. Priprema test podataka

```sql
-- Pronađi završenu performancu (StartTime < NOW() - 2 sata)
SELECT TOP 1 p.Id, p.ShowId, p.StartTime
FROM Performances p
WHERE p.StartTime < DATEADD(HOUR, -2, GETUTCDATE())
ORDER BY p.StartTime DESC;

-- Provjeri da korisnik ima skeniranu kartu za tu performancu
SELECT t.Id, t.Status, oi.PerformanceId, o.UserId
FROM Tickets t
INNER JOIN OrderItems oi ON t.OrderItemId = oi.Id
INNER JOIN Orders o ON oi.OrderId = o.Id
WHERE t.Status = 1 -- Scanned
AND oi.PerformanceId = @PerformanceId
AND o.UserId = @UserId; -- user@sapplauz.ba ID
```

### 2. Kreiraj recenziju (ako ima skeniranu kartu)

```http
POST http://localhost:5169/api/reviews
Authorization: Bearer {token}
Content-Type: application/json

{
  "showId": 1,
  "rating": 5,
  "comment": "Odlična predstava!"
}
```

Očekivano: `201 Created` ili `200 OK` (ako recenzija već postoji - ažurira se)

### 3. Pokušaj kreirati recenziju bez skenirane karte

```http
POST http://localhost:5169/api/reviews
Authorization: Bearer {token}
Content-Type: application/json

{
  "showId": 2, -- show za koji korisnik NEMA skeniranu kartu
  "rating": 5,
  "comment": "Pokušaj recenzije bez karte"
}
```

Očekivano: `400 Bad Request` sa porukom "Možete ostaviti recenziju samo nakon što odgledate predstavu..."

### 4. Testiraj cache invalidation

```http
# Prvo dohvati preporuke (kešira se)
GET http://localhost:5169/api/recommendations
Authorization: Bearer {token}

# Zatim kreiraj ili ažuriraj recenziju
POST http://localhost:5169/api/reviews
Authorization: Bearer {token}
Content-Type: application/json

{
  "showId": 1,
  "rating": 5,
  "comment": "Ažurirana recenzija"
}

# Ponovo dohvati preporuke (cache bi trebao biti invalidiran)
GET http://localhost:5169/api/recommendations
Authorization: Bearer {token}
```

---

## Napomene

1. **Database Migration:** Za `UpdatedAt` polje u `Review` entitetu, možda je potrebna migracija:
   ```powershell
   cd backend
   dotnet ef migrations add AddUpdatedAtToReview --project SApplauz.Infrastructure --startup-project SApplauz.API
   dotnet ef database update --project SApplauz.Infrastructure --startup-project SApplauz.API
   ```

2. **Cache Testing:** Potpuna provjera cache invalidation zahtijeva:
   - Dohvatiti preporuke prije recenzije
   - Kreirati recenziju
   - Provjeriti da se cache invalidira (novi zahtjev ne vraća stari cache)

3. **Test Data Setup:** Za potpuno testiranje, potrebno je:
   - Korisnik sa skeniranom kartom za završenu predstavu
   - Korisnik sa ne-skeniranom kartom za završenu predstavu
   - Korisnik sa kartom za buduću predstavu
   - Različite kombinacije Show + Performance + Ticket status

---

## Sljedeći koraci

- [x] Implementirati validaciju za recenziranje (skenirana karta + završen termin)
- [x] Omogućiti ažuriranje postojećih recenzija (umjesto blokiranja duplikata)
- [x] Dodati caching u RecommendationService
- [x] Invalidirati cache nakon kreiranja/ažuriranja recenzije
- [x] Invalidirati cache nakon kupovine karata
- [ ] Kreirati database migraciju za UpdatedAt polje (ako već ne postoji)
- [ ] Dodati unit testove za `ReviewService.ValidateReviewEligibilityAsync`
- [ ] Integrirati testove u CI/CD pipeline
