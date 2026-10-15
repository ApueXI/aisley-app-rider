# Aisley Courier

Aisley Courier is the external Flutter/Dart application for Aisley Couriers. It is a Courier client, not a Customer, Seller, Admin, or Logistics dashboard.

The app implements Auth v2.6 response handling, account/vehicle/policy, notifications with authorized pickup/final-mile navigation, first-mile pickup/filtering and scanning, final-mile batch acceptance/hub handoff, photo POD/COD completion intent, failed-attempt reporting, exact-reference history search, read-only MapLibre routes, dashboard v2 with default-v1 preview fallback, and Logistics/Seller/Buyer chat with image upload/viewing and received MP4/documents. Live authenticated/deployed API, media runtime and installed-device acceptance remain open.

Historical adoption slices and current source inspection are recorded in [Progress](docs/PROGRESS.md) and the [October 12 audit](docs/references/synchronization-2026-10-12.md). The app has no forgot-password flow or linehaul screens. Auth response integration is implemented locally; recovery presentation and authenticated acceptance remain open.

Frontend work follows the shared [Courier design guide](docs/design-courier.md): familiar Material interactions, consistent labels and navigation, and focused decisions based on Jakob's Law and Hick's Law. [AGENTS.md](AGENTS.md) requires review of changed screens against those rules; feature specs continue to define the authorized workflow.

## Requirements

- Flutter SDK compatible with the lockfile (Flutter >= 3.44.0, Dart >= 3.13.2 and < 4.0.0). The verified local and CI baseline is stable Flutter 3.47.2 / Dart 3.13.2.
- Git.
- A reachable Laravel API implementing the versioned `/api/v1` Courier contract.
- A platform toolchain for the target you want to run.

Check the local installation before setup:

```bash
flutter --version
flutter doctor -v
```

Official setup references:

- [Install Flutter](https://docs.flutter.dev/get-started/install)
- [Linux desktop setup](https://docs.flutter.dev/platform-integration/linux/setup)
- [Web setup](https://docs.flutter.dev/platform-integration/web/setup)
- [Windows desktop setup](https://docs.flutter.dev/platform-integration/windows/setup)

## Clone and configure

From the cloned repository root:

```bash
git clone <repository-url>
cd aisley_app
cp .env.example .env
flutter pub get
flutter doctor -v
flutter analyze
flutter test
```

The app loads the project-root `.env` asset before creating API clients. Set the four values in your local configuration for your environment:

```dotenv
MAPS_ENABLED=true
GEOAPIFY_API_KEY=
API_BASE_URL=http://127.0.0.1:8000
STOREFRONT_ORIGIN=
```

`API_BASE_URL` is the Laravel origin without `/api/v1`; the app appends that prefix. A blank value keeps `http://127.0.0.1:8000`; Android emulators normally use `http://10.0.2.2:8000`. Use HTTPS outside local development. `MAPS_ENABLED=false` disables map rendering and style/tile requests while keeping route stops and delivery actions available; blank defaults to `true` to preserve existing behavior. The flag also accepts `1`/`0` and never overrides server authorization or availability.

`GEOAPIFY_API_KEY` and `STOREFRONT_ORIGIN` are loaded as optional configuration. Current Courier features do not consume them: maps use the authenticated Laravel proxy, and the app has no storefront navigation. Leave these values blank unless needed by a separately approved feature; never use a server-only Geoapify key here.

The `.env` file stays Git-ignored but is bundled into Android, desktop, and web builds, where its contents are readable. Keep it limited to public client configuration; never include passwords, bearer tokens, private provider keys, or other secrets. Values support comments, optional `export`, and single/double quotes; multiline values and variable interpolation are unsupported. Run or rebuild the app after changing `.env`; the usual `flutter run` and `flutter build` commands need no Dart defines. A missing `.env` stops asset builds; runtime loading or parsing failures use the existing startup error/retry screen without logging its contents.

If the Laravel API is running on another machine, use a development-machine address reachable from the target platform and configure the API's CORS policy for browser runs. The app shows a recoverable network state when the API is unavailable.

## Run on Linux desktop

Linux is the currently committed desktop runner and the normal local development target.

On Ubuntu/Debian, install the Flutter Linux and secure-storage prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev \
  libsecret-1-0 libsecret-1-dev gnome-keyring libjsoncpp-dev
```

### Linux secure storage and keyring

The app uses `flutter_secure_storage` for its bearer token. Linux needs both
the `libsecret` runtime/development packages and a running Secret Service
provider such as GNOME Keyring. Installing only the development package may
allow compilation but still cause secure-storage errors when the app starts.

After installing the packages, log out and back in so the desktop session can
start and unlock the keyring before running the app. On a non-GNOME session or
window manager, make sure its session startup provides a D-Bus user session and
starts a Secret Service provider. If the app reports that secure storage is
unavailable, check the session keyring before troubleshooting the API:

```bash
gnome-keyring-daemon --start --components=secrets
flutter run -d linux
```

Do not replace secure storage with plaintext files, ordinary preferences, or
hard-coded tokens. See the [`flutter_secure_storage_linux` requirements](https://pub.dev/documentation/flutter_secure_storage_linux/latest/)
for platform-specific alternatives and package details.

Enable and verify Linux desktop support:

```bash
flutter config --enable-linux-desktop
flutter devices
```

Run the app:

```bash
flutter run -d linux
```

Create a release build:

```bash
flutter build linux --release
```

## Run in a browser

The existing `web/` runner serves the **same Flutter Courier app** for local development and camera testing. It is not a separate Courier web dashboard. Use a fixed local origin so API CORS and camera permissions can be tested consistently:

```bash
flutter run -d web-server --web-hostname localhost --web-port 8765
```

Open `http://localhost:8765` in your browser. Browser webcam access requires permission and a secure context such as localhost; a non-local browser test needs HTTPS. Allow the exact Flutter origin in the Laravel API's CORS configuration. See the [Flutter web-server guide](https://docs.flutter.dev/platform-integration/web/setup) and [browser camera requirements](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia).

Camera scanning uses the shared Flutter scanner for QR and Code 128 tracking-ID candidates in the first-mile pickup flow. It fills the pickup input and never submits an action automatically. Final-mile proof is photo-only: Android uses a separate rear-camera still capture, while localhost web uses the file chooser. If scanner permission or browser support is unavailable, use manual first-mile input; do not use a plaintext token workaround. The API must allow the exact localhost origin for authenticated web testing.

The shared multipart sender now keeps Android/native readable-path uploads and uses bounded selected-file bytes in the browser. Registration evidence, profile photos, vehicle documents, and delivery photo POD use this platform-safe transport. Browser CORS/private-read behavior and installed-APK uploads still require runtime acceptance against a reachable API; build success alone does not verify either target. See the [cross-platform upload guide](docs/flutter-file-uploads.md), and allow the exact localhost origin plus the required upload/private-read preflights in the API.

## Run on Android and build an APK

Android uses the existing `android/` runner. To build an installable release APK:

```bash
flutter build apk --release
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The release APK includes camera permission, the first-mile QR/Code 128 scanner, and dedicated final-mile rear-camera still capture. Verify scanner and POD capture/permission states on an installed release APK; first-mile manual entry and POD file fallback remain available. A successful build alone does not prove either physical camera flow works.

## Run on Windows desktop

Windows desktop builds must be run on Windows. Install Flutter and Visual Studio with the **Desktop development with C++** workload; Visual Studio Code alone is not the Windows C++ toolchain.

This checkout does not include a `windows/` runner directory. Generate it once from the project root when working on Windows:

```powershell
flutter create --platforms=windows .
```

Enable and verify Windows desktop support:

```powershell
flutter config --enable-windows-desktop
flutter doctor -v
flutter devices
```

Run the app:

```powershell
flutter run -d windows
```

Create a release build:

```powershell
flutter build windows --release
```

## Useful development commands

[Courier quality checks](.github/workflows/flutter-quality.yml) runs on every push and pull request, with no branch or path filters, and supports manual dispatch from GitHub Actions. Its single `quality` job uses Ubuntu 24.04, a 15-minute timeout, read-only repository permissions, and cancellation of superseded runs on the same ref. It caches the Flutter SDK and dependencies; the dependency cache key includes the lockfile hash.

CI creates its public test configuration from `.env.example`. Run the same checks locally after creating your `.env`, in order:

```bash
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

Any failed command fails CI. [Lockfile enforcement](https://dart.dev/tools/pub/cmd/pub-get#enforce-lockfile) rejects an invalid dependency resolution or changed hosted-package hashes instead of silently updating dependencies. Formatting is excluded from CI. The existing mocked tests require no credentials or running Laravel API; passing CI does not establish live backend or installed-device acceptance. The hosted workflow remains unverified until it runs on GitHub.

Other local commands:

```bash
flutter analyze
flutter test
flutter devices
```

Keep API calls in the client/repository layers, keep bearer tokens in secure storage, and follow the rules in [AGENTS.md](AGENTS.md) before changing Courier behavior.
