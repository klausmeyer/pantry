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

OIDC settings (optional overrides):

```bash
flutter run \
  --dart-define=PANTRY_OIDC_ISSUER=http://localhost:8081/realms/test \
  --dart-define=PANTRY_OIDC_CLIENT_ID=pantry \
  --dart-define=PANTRY_OIDC_REDIRECT_URI=com.pantry.app:/oauthredirect
```

## OIDC Redirect Setup

After running `flutter create .`, update the platform configs so the redirect URI can return to the app.

Android (`mobile/android/app/src/main/AndroidManifest.xml`) inside the `<activity>`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.pantry.app" android:host="oauthredirect" />
</intent-filter>
```

iOS (`mobile/ios/Runner/Info.plist`) add:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.pantry.app</string>
    </array>
  </dict>
</array>
```

If you prefer a different scheme, update both the redirect URI and these entries.

## Notes

- This app is intentionally minimal right now and will be expanded as the backend and API stabilize.
- OIDC authentication will be integrated once the API flows are finalized.
