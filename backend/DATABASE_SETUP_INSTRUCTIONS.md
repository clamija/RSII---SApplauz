# 📋 Upute za postavljanje baze podataka - Finalna verzija

## ✅ Šta je urađeno:

1. ✅ Dodato `Capacity` u `Institution` (uklonjeno `City`)
2. ✅ Dodato `ImagePath` i `Website` u `Institution`
3. ✅ Dodato `ImagePath` i `GenreId` u `Show` (uklonjeno `ShowGenre` tabela - M:N → 1:N)
4. ✅ Uklonjeno `TotalSeats` iz `Performance` (koristi se `Institution.Capacity`)
5. ✅ Kreirana migracija: `UpdateEntitiesRemoveShowGenreAddImagePathWebsite`
6. ✅ Kreirana SQL skripta: `INSERT_DATA.sql` sa svim podacima

---

## 🚀 Redosljed pokretanja:

### KORAK 1: Priprema baze (jednom)

Pokrenite u SQL Server Management Studio:
```sql
-- Pokrenite SETUP_ASP_TABLES.sql
-- Ovo briše sve podatke i dodaje samo uloge
```

### KORAK 2: Pokretanje API-a (primjenjuje migracije)

1. Otvorite Visual Studio 2022
2. Pokrenite `SApplauz.API` projekt
3. API će automatski:
   - Primijeniti migracije (dodati nove kolone, ukloniti stare)
   - Kreirati test korisnike (DatabaseSeeder)

### KORAK 3: Unos podataka

Pokrenite u SQL Server Management Studio:
```sql
-- Pokrenite INSERT_DATA.sql
-- Ovo dodaje:
--   - 8 institucija (sa ImagePath i Website)
--   - 5 žanrova
--   - 17 predstava (sa ImagePath i GenreId)
--   - 24 termina izvođenja (sa AvailableSeats = Capacity)
```

---

## 📁 Struktura slika

Slike trebate postaviti u folder:
```
backend/SApplauz.API/wwwroot/images/
```

**Nazivi slika:**

### Institucije:
- `narodno-pozoriste-sarajevo.png`
- `kamerni-teatar-55.png`
- `sarajevski-ratni-teatar.png`
- `pozoriste-mladih-sarajevo.png`
- `otvorena-scena-obala.png`
- `ju-centar-kulture-i-mladih.png`
- `bosanski-kulturni-centar.png`
- `dom-mladih-skenderija.png`

### Predstave:
- `sarajevo-moje-drago.png`
- `marlene-dietrich-pet-tacaka-optuznice.png`
- `na-slovo-f.png`
- `snjeguljica-i-sedam-patuljaka.png`
- `ona.png`
- `malogradanska-svadba.png`
- `otac.png`
- `ljubavnice.png`
- `totovi.png`
- `za-zivot-cijeli.png`
- `njih-vise-nema.png`
- `podroom.png`
- `ne-daj-se-generacijo.png`
- `cvrcek-i-mrav.png`
- `dovidjenja.png`
- `tajni-dnevnik-adriana-molea.png`
- `patrolne-sape.png`

---

## ✅ Provjera

Nakon pokretanja svih koraka, provjerite u SQL Server Management Studio:

```sql
-- Provjera institucija
SELECT COUNT(*) AS 'Broj institucija' FROM Institutions; -- Trebalo bi biti: 8

-- Provjera žanrova
SELECT COUNT(*) AS 'Broj žanrova' FROM Genres; -- Trebalo bi biti: 5

-- Provjera predstava
SELECT COUNT(*) AS 'Broj predstava' FROM Shows; -- Trebalo bi biti: 17

-- Provjera termina
SELECT COUNT(*) AS 'Broj termina' FROM Performances; -- Trebalo bi biti: 24

-- Provjera korisnika
SELECT COUNT(*) AS 'Broj korisnika' FROM AspNetUsers; -- Trebalo bi biti: 18
```

---

## 🎯 Napomene

1. **AvailableSeats u Performances**: Automatski se postavlja na `Institution.Capacity` kada se kreira Performance kroz API
2. **ImagePath format**: Sve slike moraju biti u PNG formatu, sve malim slovima, sa crticama umjesto razmaka
3. **Website**: Sve institucije imaju svoje web stranice
4. **Genre**: Svaka predstava ima samo jedan žanr (1:N veza)

---

## 🐛 Ako imate problema:

1. **Migracija ne prolazi**: Provjerite da li ste prvo pokrenuli `SETUP_ASP_TABLES.sql`
2. **FK constraint greška**: Osigurajte se da su podaci uneseni u pravom redosljedu:
   - Prvo: Institutions
   - Drugo: Genres
   - Treće: Shows
   - Četvrto: Performances
3. **AvailableSeats = 0**: Provjerite da li je `Institution.Capacity` ispravno postavljen

---

**Sve je spremno! 🎉**

