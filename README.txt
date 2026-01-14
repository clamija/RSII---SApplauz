# SApplauz

SApplauz is a theatre repertoire and ticketing platform (backend + Flutter mobile & desktop apps).

## Project structure

```
SApplauz/
├── backend/              # .NET 9 backend (API + Worker)
├── mobile/               # Flutter mobile app
├── desktop/              # Flutter desktop app (Windows)
└── docker-compose.yml    # Local infrastructure (SQL Server, RabbitMQ, API, Worker)
```

## Prerequisites

- Docker Desktop (with Compose)
- Flutter SDK
  - Android Studio (for Android) and/or Xcode (for iOS)
  - Windows desktop support enabled for Flutter (for the desktop app)

## Run the application

### Backend (recommended: Docker Compose)

From the repository root:

```bash
docker compose up -d --build
```

- **API**: `http://localhost:5000/swagger`
- **RabbitMQ Management UI**: `http://localhost:15672` (user: `admin`, pass: `admin123`)

> Note: Database seeding is enabled on startup (see `backend/SApplauz.API/appsettings.json` → `ApiSettings:SeedOnStartup`).

### Mobile app

```bash
cd mobile
flutter pub get
flutter run
```

> Android emulator uses `10.0.2.2` to access host `localhost`. Base URL logic is handled in `mobile/lib/utils/image_helper.dart` and the API client in `packages/sapplauz_core/lib/services/api_service.dart`.

### Desktop app (Windows)

```bash
cd desktop
flutter pub get
flutter run -d windows
```

## Login credentials (seeded)

Authentication is done via **username + password**.

## Registration & role testing

You can also register using email: `adil@edu.fit.ba`. After registration, you can change user roles using the SuperAdmin account, allowing you to test registration, login, and permissions for each role in the application.

### Required accounts

- **Desktop version**
  - Username: `desktop`
  - Password: `test`
- **Mobile version**
  - Username: `mobile`
  - Password: `test`

### Additional roles (format: `username` / `test`)

- **SuperAdmin**: `superadmin` / `test`
- **Institution Admins**: `adminNPS`, `adminKT`, `adminSARTR`, `adminPOZM`, `adminOS`, `adminCK`, `adminBKC`, `adminDM` / `test`
- **Cashiers (Blagajnik)**: `blagajnikNPS`, `blagajnikKT`, `blagajnikSARTR`, `blagajnikPOZM`, `blagajnikOS`, `blagajnikCK`, `blagajnikBKC`, `blagajnikDM` / `test`
- **Users (Korisnik)**: `korisnik1` … `korisnik6` / `test`

## Useful commands

- **Stop**:

```bash
docker compose down
```

- **Reset local data (⚠ deletes volumes)**:

```bash
docker compose down -v
```

