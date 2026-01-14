# FAZA 7: Backend - Referentni podaci i CRUD - Testiranje

## Pregled

FAZA 7 osigurava da su svi referentni podaci (Genres, Institutions) upravljivi sa Desktop-a sa potpunim CRUD operacijama i validacijom prije brisanja.

## Implementirano

### 7.1 GenresController - Proširenje
- ✅ Sve Genre CRUD operacije implementirane:
  - GET /api/genres - Dohvati sve žanrove
  - GET /api/genres/{id} - Dohvati žanr po ID-u
  - POST /api/genres - Kreiraj novi žanr (SuperAdmin)
  - PUT /api/genres/{id} - Ažuriraj žanr (SuperAdmin)
  - DELETE /api/genres/{id} - Obriši žanr (SuperAdmin)
- ✅ Validacija: ne dozvoliti brisanje ako se koristi u Shows
- ✅ Jasna poruka: "Ne možete obrisati žanr jer se koristi u X predstava/predstavi"

### 7.2 InstitutionsController
- ✅ Sve Institution CRUD operacije implementirane:
  - GET /api/institutions - Dohvati sve institucije
  - GET /api/institutions/{id} - Dohvati instituciju po ID-u
  - POST /api/institutions - Kreiraj novu instituciju (SuperAdmin)
  - PUT /api/institutions/{id} - Ažuriraj instituciju (SuperAdmin)
  - DELETE /api/institutions/{id} - Obriši instituciju (SuperAdmin)
- ✅ SuperAdmin može sve CRUD operacije

### 7.3 Validacija referentnih podataka
- ✅ Prije brisanja Genre: provjerava da li se koristi u Shows
- ✅ Prije brisanja Institution: provjerava da li se koristi u Shows
- ✅ Jasne poruke na hrvatskom:
  - "Ne možete obrisati žanr jer se koristi u X predstava/predstavi"
  - "Ne možete obrisati instituciju jer se koristi u X predstava/predstavi"

### 7.4 Success Messages
- ✅ "Žanr je uspješno kreiran"
- ✅ "Žanr je uspješno ažuriran"
- ✅ "Žanr je uspješno obrisan"
- ✅ "Institucija je uspješno kreirana" (već implementirano u FAZI 6)
- ✅ "Institucija je uspješno ažurirana" (već implementirano u FAZI 6)
- ✅ "Institucija je uspješno obrisana"

## Pokretanje testova

### Preduslovi
1. API mora biti pokrenut na `http://localhost:5169`
2. Baza podataka mora biti seed-ovana sa test podacima
3. Korisnik `superadmin@sapplauz.ba` mora postojati (password: `SuperAdmin123!`)

### Pokretanje test skripte

```powershell
cd backend/SApplauz.API/tests
.\Test-Faza7.ps1
```

### Test slučajevi

1. **TEST 1: GenresController - GET all genres**
   - Provjerava da li se mogu dohvatiti svi žanrovi
   - Očekivano: Lista žanrova

2. **TEST 2: GenresController - GET genre by ID**
   - Provjerava da li se može dohvatiti žanr po ID-u
   - Očekivano: Genre objekt

3. **TEST 3: GenresController - CREATE genre**
   - Provjerava da li se može kreirati novi žanr
   - Očekivano: Success message "Žanr je uspješno kreiran"

4. **TEST 4: GenresController - UPDATE genre**
   - Provjerava da li se može ažurirati žanr
   - Očekivano: Success message "Žanr je uspješno ažuriran"

5. **TEST 5: GenresController - DELETE genre (bez Shows)**
   - Provjerava da li se može obrisati žanr koji se ne koristi u Shows
   - Očekivano: Success message "Žanr je uspješno obrisan"

6. **TEST 6: GenresController - DELETE genre (sa Shows) - validacija**
   - Provjerava da li se vraća greška pri pokušaju brisanja žanra koji se koristi u Shows
   - Očekivano: 400 Bad Request sa porukom "Ne možete obrisati žanr jer se koristi u X predstava/predstavi"

7. **TEST 7: InstitutionsController - GET all institutions**
   - Provjerava da li se mogu dohvatiti sve institucije
   - Očekivano: Lista institucija

8. **TEST 8: InstitutionsController - GET institution by ID**
   - Provjerava da li se može dohvatiti institucija po ID-u
   - Očekivano: Institution objekt

9. **TEST 9: InstitutionsController - DELETE institution (sa Shows) - validacija**
   - Provjerava da li se vraća greška pri pokušaju brisanja institucije koja se koristi u Shows
   - Očekivano: 400 Bad Request sa porukom "Ne možete obrisati instituciju jer se koristi u X predstava/predstavi"

## Rezultati testiranja

Svi testovi prolaze (9/9):
- ✅ TEST 1: GET all genres
- ✅ TEST 2: GET genre by ID
- ✅ TEST 3: CREATE genre
- ✅ TEST 4: UPDATE genre
- ✅ TEST 5: DELETE genre (bez Shows)
- ✅ TEST 6: DELETE genre (sa Shows) - validacija
- ✅ TEST 7: GET all institutions
- ✅ TEST 8: GET institution by ID
- ✅ TEST 9: DELETE institution (sa Shows) - validacija

## Implementirane izmjene

### Servisi
- `GenreService.cs` - Poboljšana validacija prije brisanja sa specifičnom porukom
- `InstitutionService.cs` - Poboljšana validacija prije brisanja sa specifičnom porukom

### Kontroleri
- `GenresController.cs` - Dodani success messages za sve CRUD operacije
- `InstitutionsController.cs` - Dodan success message za DELETE operaciju

## Napomene

- Success messages mogu imati varijacije sa/bez dijakritika ovisno o JSON encoding-u
- Validacija prije brisanja provjerava broj Shows koji koriste Genre/Institution
- Poruke koriste pravilnu gramatiku (predstava/predstava) ovisno o broju
