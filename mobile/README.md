# Pantry Mobile (Flutter)

This is the Flutter mobile app for Pantry. It supports OIDC login, item CRUD,
image uploads, and best-before badges.

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

## Features

- OIDC login with token refresh and secure storage.
- List, create, edit, and delete pantry items.
- Best-before badge with day countdown.
- Image upload with presigned URLs and in-app preview.

## Image Uploads

- Images are resized before upload to match the web frontend:
  - Max dimension: `1600px`
  - JPEG/WebP quality: `0.85`
  - PNG stays lossless
- Supported upload types follow the backend (jpeg/jpg/png/webp/gif).

## iOS Photo Permission

The app uses the photo library picker for image uploads. Ensure the usage
string is present in `mobile/ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Pantry needs access to your photos to upload item pictures.</string>
```

## Token Storage

Access, ID, and refresh tokens are stored with `flutter_secure_storage`, which uses
Keychain on iOS and the Android Keystore-backed storage on Android.

## Notes

- If you use a physical device, replace `localhost` with your machine’s LAN IP
  for the API and OIDC issuer.
