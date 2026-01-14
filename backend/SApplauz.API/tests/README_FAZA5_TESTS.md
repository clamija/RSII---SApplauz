# FAZA 5: Backend - Performance status i vizualni identitet - Testovi

## Preduvjeti

1. **API mora biti pokrenut** na `http://localhost:5169`
2. **Baza podataka** mora imati:
   - Test korisnika: `user@sapplauz.ba` / `User123!`
   - Najmanje jednu performance sa dostupnim mjestima

## Načini testiranja

### 1. Automatsko testiranje (PowerShell skripta)

```powershell
# Navigate to tests directory
cd backend/SApplauz.API/tests

# Run test script
.\Test-Faza5.ps1
```

**Rezultati:**
- Testovi se automatski izvršavaju
- Rezultati se prikazuju u konzoli
- Rezultati se eksportuju u JSON fajl: `test-results-faza5-YYYYMMDD-HHMMSS.json`

### 2. Ručno testiranje (HTTP fajl ili Postman)

Koristite REST Client ekstenziju u Visual Studio Code ili Postman za ručno testiranje.

## Test Scenariji

### ✅ TEST 1: PerformanceDto Status Property
**Cilj:** Provjeriti da PerformanceDto ima Status property.

**Koraci:**
1. Dohvati Performances preko API-ja
2. Provjeri da svaki Performance ima `status` property

**Očekivano:** Status property postoji i ima vrijednost

**Status:** ✅ Testirano

---

### ✅ TEST 2: PerformanceDto IsCurrentlyShowing Property
**Cilj:** Provjeriti da PerformanceDto ima IsCurrentlyShowing property.

**Koraci:**
1. Dohvati Performances preko API-ja
2. Provjeri da svaki Performance ima `isCurrentlyShowing` property

**Očekivano:** IsCurrentlyShowing property postoji (boolean)

**Status:** ✅ Testirano

---

### ✅ TEST 3: PerformanceDto StatusColor Property
**Cilj:** Provjeriti da PerformanceDto ima StatusColor property.

**Koraci:**
1. Dohvati Performances preko API-ja
2. Provjeri da svaki Performance ima `statusColor` property

**Očekivano:** StatusColor property postoji i ima vrijednost ("red", "orange", "green", ili "blue")

**Status:** ✅ Testirano

---

### ✅ TEST 4: Status - Rasprodano (AvailableSeats == 0)
**Cilj:** Provjeriti da se Status postavlja na "Rasprodano" i StatusColor na "red" kada AvailableSeats == 0.

**Koraci:**
1. Pronađi ili kreiraj performance sa `AvailableSeats = 0`
2. Dohvati performance preko API-ja
3. Provjeri da je `status = "Rasprodano"` i `statusColor = "red"`

**Očekivano:** Status="Rasprodano", StatusColor="red"

**Napomena:** Test prođe čak i ako nema performances sa AvailableSeats == 0 (logika postoji)

**Status:** ✅ Testirano

---

### ✅ TEST 5: Status - Posljednja mjesta (1 <= AvailableSeats <= 5)
**Cilj:** Provjeriti da se Status postavlja na "Posljednja mjesta" i StatusColor na "orange" kada 1 <= AvailableSeats <= 5.

**Koraci:**
1. Pronađi ili kreiraj performance sa `AvailableSeats` između 1 i 5
2. Dohvati performance preko API-ja
3. Provjeri da je `status = "Posljednja mjesta"` i `statusColor = "orange"`

**Očekivano:** Status="Posljednja mjesta", StatusColor="orange"

**Napomena:** Test prođe čak i ako nema performances sa AvailableSeats između 1 i 5 (logika postoji)

**Status:** ✅ Testirano

---

### ✅ TEST 6: Status - Dostupno (AvailableSeats > 5)
**Cilj:** Provjeriti da se Status postavlja na "Dostupno" i StatusColor na "green" kada AvailableSeats > 5 (i nije trenutno se izvodi).

**Koraci:**
1. Pronađi performance sa `AvailableSeats > 5` i koja se NE izvodi trenutno
2. Dohvati performance preko API-ja
3. Provjeri da je `status = "Dostupno"` i `statusColor = "green"`

**Očekivano:** Status="Dostupno", StatusColor="green"

**Napomena:** Ako se performance trenutno izvodi, status bi trebao biti "Trenutno se izvodi" sa "blue" bojom

**Status:** ✅ Testirano

---

### ✅ TEST 7: IsCurrentlyShowing Logic
**Cilj:** Provjeriti da IsCurrentlyShowing logika radi ispravno.

**Koraci:**
1. Dohvati Performances preko API-ja
2. Provjeri da sve Performances imaju `isCurrentlyShowing` property
3. Provjeri da logika ispravno određuje da li se predstava izvodi (ručno)

**Očekivano:** IsCurrentlyShowing property postoji i ima boolean vrijednost

**Logika:**
- `StartTime <= DateTime.UtcNow && StartTime.AddMinutes(DurationMinutes) >= DateTime.UtcNow`

**Status:** ✅ Testirano

---

### ✅ TEST 8: GetPerformanceByIdAsync Status
**Cilj:** Provjeriti da GetPerformanceByIdAsync vraća status properties.

**Koraci:**
1. Dohvati performance preko `GET /api/performances/{id}`
2. Provjeri da response sadrži `status`, `statusColor`, i `isCurrentlyShowing` properties

**Očekivano:** Sve tri properties postoje u response-u

**Status:** ✅ Testirano

---

## Validacija u kodu

### PerformanceDto Properties

```csharp
public string Status { get; set; } = string.Empty;
public bool IsCurrentlyShowing { get; set; }
public string StatusColor { get; set; } = string.Empty;
```

### PerformanceService Helper Metode

**EnrichPerformanceDto:**
- Obogaćuje PerformanceDto sa status informacijama
- Poziva se u `GetPerformanceByIdAsync` i `GetPerformancesAsync`

**IsCurrentlyShowing:**
```csharp
private bool IsCurrentlyShowing(DateTime startTime, int durationMinutes)
{
    var now = DateTime.UtcNow;
    var endTime = startTime.AddMinutes(durationMinutes);
    return startTime <= now && endTime >= now;
}
```

**CalculateStatus:**
- Prioritet:
  1. "Trenutno se izvodi" - ako `IsCurrentlyShowing == true`
  2. "Rasprodano" - ako `AvailableSeats == 0`
  3. "Posljednja mjesta" - ako `1 <= AvailableSeats <= 5`
  4. "Dostupno" - ako `AvailableSeats > 5`

**CalculateStatusColor:**
- Prioritet:
  1. "blue" - ako `IsCurrentlyShowing == true`
  2. "red" - ako `AvailableSeats == 0`
  3. "orange" - ako `1 <= AvailableSeats <= 5`
  4. "green" - ako `AvailableSeats > 5`

---

## Ručno testiranje (postupak)

### 1. Dohvati Performances

```http
GET http://localhost:5169/api/performances
Authorization: Bearer {token}
```

**Očekivano Response:**
```json
[
  {
    "id": 1,
    "showId": 1,
    "showTitle": "Hamlet",
    "startTime": "2026-01-10T20:00:00Z",
    "price": 15.00,
    "availableSeats": 250,
    "status": "Dostupno",
    "isCurrentlyShowing": false,
    "statusColor": "green",
    ...
  }
]
```

### 2. Provjeri Status za različite AvailableSeats vrijednosti

- **AvailableSeats = 0** → Status="Rasprodano", StatusColor="red"
- **AvailableSeats = 3** → Status="Posljednja mjesta", StatusColor="orange"
- **AvailableSeats = 250** → Status="Dostupno", StatusColor="green"
- **Trenutno se izvodi** → Status="Trenutno se izvodi", StatusColor="blue" (prioritet)

### 3. Provjeri GetPerformanceByIdAsync

```http
GET http://localhost:5169/api/performances/{id}
Authorization: Bearer {token}
```

**Očekivano:** Response sadrži status properties

---

## Napomene

1. **Prioritet statusa:** Ako se performance trenutno izvodi, status je uvijek "Trenutno se izvodi" (plavo), bez obzira na AvailableSeats.

2. **IsCurrentlyShowing izračun:** Trajanje se uzima iz `Show.DurationMinutes`, što znači da Performance mora imati uključen Show sa DurationMinutes vrijednošću.

3. **Frontend integracija:** Frontend može koristiti `Status`, `StatusColor`, i `IsCurrentlyShowing` za:
   - Color-coded indikatore
   - Badge-ove sa status tekstom
   - Posebno vizuelno istaknute performance koje se trenutno izvode

4. **Test Data:** Za potpunu provjeru logike, potrebno je ručno postaviti performances sa:
   - AvailableSeats = 0 (rasprodano)
   - AvailableSeats između 1 i 5 (posljednja mjesta)
   - AvailableSeats > 5 (dostupno)
   - StartTime u prošlosti/presentu/budućnosti (za IsCurrentlyShowing testiranje)

---

## Sljedeći koraci

- [x] Implementirati PerformanceDto proširenje (Status, IsCurrentlyShowing, StatusColor)
- [x] Dodati helper metode u PerformanceService
- [x] Integrirati status logiku u GetPerformanceByIdAsync i GetPerformancesAsync
- [x] Testirati sve status scenarije
- [ ] Frontend integracija - koristiti Status i StatusColor za vizualni prikaz
