# SApplauz Mobile App

Mobilna aplikacija za SApplauz platformu - objedinjena pozorišna scena Sarajeva.

## Funkcionalnosti

- ✅ Login sa JWT autentifikacijom
- ✅ Registracija novih korisnika
- ✅ Automatsko čuvanje tokena
- ✅ Home ekran sa korisničkim informacijama
- ✅ Logout funkcionalnost

## Pokretanje

```bash
cd mobile
flutter pub get
flutter run
```

## Test Korisnici

- **SuperAdmin:** `superadmin@sapplauz.ba` / `SuperAdmin123!`
- **Admin Institucije:** `admin@sapplauz.ba` / `Admin123!`
- **Blagajnik:** `blagajnik@sapplauz.ba` / `Blagajnik123!`
- **User:** `user@sapplauz.ba` / `User123!`

## API Konfiguracija

API base URL je konfigurisan u `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://localhost:5169/api';
```

Za Android emulator, koristite `10.0.2.2` umjesto `localhost`:
```dart
static const String baseUrl = 'http://10.0.2.2:5169/api';
```

## Struktura Projekta

```
lib/
├── models/          # Data models (User, LoginRequest, itd.)
├── services/        # API i storage servisi
└── screens/         # UI ekrani (Login, Register, Home)
```
