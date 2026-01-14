# FAZA 8: Flutter Mobile - Platform Split i Blagajnik funkcionalnosti

## Pregled

FAZA 8 implementira platform split između Mobile i Desktop aplikacija, osigurava filtering za Blagajnike, i poboljšava korisničke funkcionalnosti.

## Implementirano

### 8.1 Uklanjanje Admin funkcionalnosti ✅
- ✅ Obrisan `mobile/lib/screens/admin/` folder
- ✅ Uklonjen Admin dashboard iz `home_screen.dart`
- ✅ Admin korisnike preusmjereni na poruku: "Za administraciju koristite Desktop aplikaciju"
- ✅ Navigation bar uklonjen za Admin korisnike

### 8.2 Blagajnik - Filtering po instituciji ✅
- ✅ `BlagajnikDashboard`: Backend automatski filtrira termine po InstitutionId iz uloge
- ✅ `QrScannerScreen`: Automatski validira samo karte za njegovu instituciju (backend automatski određuje InstitutionId)
- ✅ API pozivi: Backend automatski dodaje InstitutionId filter na osnovu uloge korisnika

### 8.3 Korisnik - Poboljšanja ✅
- ✅ `ShowsListScreen`: Prikazuje sve predstave (bez ograničenja)
- ✅ `ShowDetailsScreen`: Prikazuje termine sa status indikatorima (boje) iz backend-a
  - Koristi `status`, `statusColor`, i `isCurrentlyShowing` iz Performance modela
  - Prikazuje status badge sa bojom
- ✅ `MyTicketsScreen`: Prikazuje samo svoje karte sa statusom
- ✅ `CheckoutScreen`: Real-time provjera dostupnosti, poruka ako je netko bio brži
  - Provjerava dostupnost prije kreiranja Order-a
  - Prikazuje poruku "Neko je bio brži" ako se dostupnost promijenila

### 8.4 Recenziranje ✅
- ✅ `ReviewScreen`: Prikazuje samo za Shows gdje korisnik ima skeniranu kartu i termin je završio
- ✅ Disable "Ostavi recenziju" ako nije ispunjen uslov
- ✅ `canReviewShow()` metoda provjerava:
  - Da li korisnik ima skeniranu kartu za tu predstavu
  - Da li je termin završio
- ✅ Link na ReviewScreen iz ShowDetailsScreen (klik na ocjenu)

### 8.5 Image helper ✅
- ✅ Kreiran `ImageHelper` sa metodom `getImageUrl(imagePath, institutionImagePath, defaultImage)`
- ✅ Koristi se u ShowsListScreen, ShowDetailsScreen (import dodan)
- ✅ Fallback logika: Show Image → Institution Image → Default Image

## Implementirane izmjene

### Obrisani fajlovi
- `mobile/lib/screens/admin/admin_dashboard.dart`

### Kreirani fajlovi
- `mobile/lib/utils/image_helper.dart` - ImageHelper klasa
- `mobile/lib/models/review.dart` - Review model i CreateReviewRequest
- `mobile/lib/screens/reviews/review_screen.dart` - ReviewScreen

### Ažurirani fajlovi
- `mobile/lib/screens/home_screen.dart`:
  - Uklonjen import `admin/admin_dashboard.dart`
  - Dodana `_buildAdminMessage()` metoda
  - Admin korisnici preusmjereni na poruku
  - Navigation bar uklonjen za Admin korisnike
  - Uklonjena neiskorištena `_buildDashboard()` metoda

- `mobile/lib/screens/blagajnik/qr_scanner_screen.dart`:
  - Uklonjen `institutionId` parametar iz `validateTicket()` poziva
  - Backend automatski određuje InstitutionId iz uloge

- `mobile/lib/services/api_service.dart`:
  - Ažurirana `validateTicket()` metoda - uklonjen `institutionId` parametar
  - Dodane `getReviews()`, `createReview()`, i `canReviewShow()` metode
  - Dodan import za Review model

- `mobile/lib/models/performance.dart`:
  - Dodana `status` property (string)
  - Dodana `isCurrentlyShowing` property (bool?)
  - Dodana `statusColor` property (string?)

- `mobile/lib/screens/shows/show_details_screen.dart`:
  - Dodan import za `ImageHelper` i `ReviewScreen`
  - Ažurirana `_buildPerformanceCard()` da koristi status iz backend-a
  - Dodan link na ReviewScreen (klik na ocjenu)

- `mobile/lib/screens/shows/shows_list_screen.dart`:
  - Dodan import za `ImageHelper`

- `mobile/lib/screens/checkout/checkout_screen.dart`:
  - Već ima real-time provjeru dostupnosti
  - Već prikazuje poruku "Neko je bio brži"

## Napomene

- Backend automatski filtrira podatke po InstitutionId iz uloge korisnika
- Blagajnik vidi samo termine i karte za svoju instituciju
- Korisnik vidi sve predstave bez ograničenja
- ReviewScreen provjerava da li korisnik ima skeniranu kartu i da li je termin završio
- ImageHelper koristi fallback logiku za slike

## Testiranje

Za testiranje FAZE 8, potrebno je:

1. **Test Admin funkcionalnosti**:
   - Login kao Admin korisnik
   - Provjeriti da se prikazuje poruka "Za administraciju koristite Desktop aplikaciju"
   - Provjeriti da nema navigation bar

2. **Test Blagajnik funkcionalnosti**:
   - Login kao Blagajnik korisnik
   - Provjeriti da BlagajnikDashboard prikazuje samo termine za njegovu instituciju
   - Provjeriti da QR Scanner validira samo karte za njegovu instituciju

3. **Test Korisnik funkcionalnosti**:
   - Login kao Korisnik
   - Provjeriti da ShowsListScreen prikazuje sve predstave
   - Provjeriti da ShowDetailsScreen prikazuje termine sa status indikatorima
   - Provjeriti da MyTicketsScreen prikazuje samo svoje karte
   - Provjeriti da CheckoutScreen prikazuje poruku "Neko je bio brži" ako je dostupnost promijenjena

4. **Test Recenziranje**:
   - Login kao Korisnik
   - Kupiti kartu za predstavu
   - Skenirati kartu (kao Blagajnik)
   - Provjeriti da ReviewScreen prikazuje "Ostavi recenziju" samo ako je termin završio
   - Provjeriti da se može kreirati/ažurirati recenzija

5. **Test Image Helper**:
   - Provjeriti da se slike prikazuju ispravno sa fallback logikom
