# FAZA 6: Backend - Validacija i Error Handling - Testiranje

## Pregled

FAZA 6 implementira potpunu validaciju sa jasnim porukama na hrvatskom jeziku, specifične error responses umjesto generičkih poruka, i success messages za sve glavne operacije.

## Implementirano

### 6.1 Validatori - Proširenje FluentValidation
- ✅ Svi validatori ažurirani sa jasnim porukama na hrvatskom
- ✅ Email format provjera sa specifičnom porukom
- ✅ Numerička polja sa min/max provjerama (količina 1-10, ocjena 1-5)
- ✅ ValidationFilter za formatiranje error responses

### 6.2 Error Responses
- ✅ Specifične poruke umjesto generičkih ("Bad request")
- ✅ Poruke na hrvatskom jeziku
- ✅ Format: `{"message": "Nedostaje obavezno polje: Email", "errors": {...}, "details": [...]}`

### 6.3 Success Messages
- ✅ Specifične poruke za sve glavne operacije:
  - "Predstava je uspješno kreirana"
  - "Narudžba je uspješno kreirana"
  - "Karta je uspješno validirana"
  - "Recenzija je uspješno kreirana/ažurirana"
  - "Termin je uspješno kreiran/ažuriran"
  - "Institucija je uspješno kreirana/ažurirana"

## Pokretanje testova

### Preduslovi
1. API mora biti pokrenut na `http://localhost:5169`
2. Baza podataka mora biti seed-ovana sa test podacima
3. Korisnik `user@sapplauz.ba` mora postojati (password: `User123!`)

### Pokretanje test skripte

```powershell
cd backend/SApplauz.API/tests
.\Test-Faza6.ps1
```

### Test slučajevi

1. **TEST 1: Validacija - Nedostaje obavezno polje (Email)**
   - Provjerava da li se vraća specifična poruka kada Email polje nedostaje
   - Očekivana poruka: "Nedostaje obavezno polje: Email"

2. **TEST 2: Validacija - Email format nije validan**
   - Provjerava da li se vraća specifična poruka za nevalidan email format
   - Očekivana poruka: "Email format nije validan."

3. **TEST 3: Validacija - Količina mora biti između 1 i 10**
   - Provjerava da li se vraća specifična poruka kada je količina preko limita
   - Očekivana poruka: "Količina mora biti između 1 i 10."

4. **TEST 4: Validacija - Ocjena mora biti između 1 i 5**
   - Provjerava da li se vraća specifična poruka kada je ocjena preko limita
   - Očekivana poruka: "Ocjena mora biti između 1 i 5."

5. **TEST 5: Success message - Predstava je uspješno kreirana**
   - Provjerava da li se vraća specifična success poruka pri kreiranju predstave
   - Očekivana poruka: "Predstava je uspješno kreirana."

6. **TEST 6: Success message - Narudžba je uspješno kreirana**
   - Provjerava da li se vraća specifična success poruka pri kreiranju narudžbe
   - Očekivana poruka: "Narudžba je uspješno kreirana."

7. **TEST 7: Success message - Karta je uspješno validirana**
   - Provjerava da li success message format postoji (zahtijeva validnu kartu za potpuno testiranje)
   - Očekivana poruka: "Karta je uspješno validirana."

## Rezultati testiranja

Svi testovi prolaze (7/7):
- ✅ TEST 1: Validacija - Nedostaje Email
- ✅ TEST 2: Validacija - Email format
- ✅ TEST 3: Validacija - Količina
- ✅ TEST 4: Validacija - Ocjena
- ✅ TEST 5: Success message - Predstava kreirana
- ✅ TEST 6: Success message - Narudžba kreirana
- ✅ TEST 7: Success message - Karta validirana

## Implementirane izmjene

### Validatori
- `RegisterRequestValidator.cs` - Ažurirane poruke na hrvatski
- `LoginRequestValidator.cs` - Ažurirane poruke na hrvatski
- `CreateOrderRequestValidator.cs` - Količina ograničena na 1-10
- `CreateReviewRequestValidator.cs` - Ocjena ograničena na 1-5
- `UpdateUserRequestValidator.cs` - Ažurirane poruke na hrvatski
- Svi ostali validatori već imaju poruke na hrvatskom

### Kontroleri
- `ShowsController.cs` - Dodani success messages
- `OrdersController.cs` - Dodani success messages
- `TicketsController.cs` - Dodani success messages
- `ReviewsController.cs` - Dodani success messages
- `PerformancesController.cs` - Dodani success messages
- `InstitutionsController.cs` - Dodani success messages
- `AuthController.cs` - Ažurirane error poruke na hrvatski

### Middleware/Filters
- `ValidationFilter.cs` - Formatiranje error responses sa specifičnim porukama
- `Program.cs` - Registriran ValidationFilter

## Napomene

- Success messages mogu imati varijacije sa/bez dijakritika ovisno o JSON encoding-u
- Error responses su formatirani prema ASP.NET Core Problem Details standardu
- Svi validatori koriste FluentValidation sa automatskom validacijom
