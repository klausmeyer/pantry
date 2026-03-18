# Pantry Mobile (Flutter)

This is the Flutter mobile app for Pantry.

## Requirements

- Flutter SDK (stable channel)
- Android Studio or Xcode for device simulators

## One-time Setup

From `mobile/`:

```bash
flutter create .
```

This generates the platform-specific folders (`android/`, `ios/`, etc.) while keeping the existing Dart source files.

## Run

```bash
flutter pub get
flutter run
```

## Configuration

The app reads the API base URL from a compile-time environment variable:

```bash
flutter run --dart-define=PANTRY_API_BASE_URL=http://localhost:4000
```

If not provided, the default is `http://localhost:4000`.

## Notes

- This app is intentionally minimal right now and will be expanded as the backend and API stabilize.
- OIDC authentication will be integrated once the API flows are finalized.
