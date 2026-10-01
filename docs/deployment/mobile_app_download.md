# Android app download website

The public page is `https://silvamangai.online/download`. The homepage links to it. No account is required to view the page or download the APK.

The website serves one fixed file at `storage/app/releases/silvamang-ai.apk`, through `/download/android`. This location is inside the existing persistent `app_storage` volume. It is not baked into the Docker image or committed to Git. Redeployment preserves it. Until a nonempty APK exists, the page shows “Download coming soon” and the file route returns 404.

## Build with the existing release key

The owner requested a signed public release only and selected an existing release key. Do not publish the old debug APK. The Gradle release build now uses `android/key.properties`; it no longer falls back to debug signing.

1. Copy `silvamang_mobile/android/key.properties.example` to `key.properties` and enter the existing keystore path, alias and passwords locally. Keep the keystore and passwords backed up privately. Both the filled properties file and keystores are ignored by Git.
2. Increment the build number beyond any installed public release. Check the current version in `pubspec.yaml` against the previous release before choosing that number.
3. From `silvamang_mobile`, build:

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://silvamangai.online/api
```

4. Verify `build/app/outputs/flutter-apk/app-release.apk` with the Android SDK `apksigner verify --verbose --print-certs` command. Compare the signer certificate SHA-256 with the previous public release to confirm update compatibility. Install and test on a phone with the previous release, including login and offline records. Keep the old app until its records are safely synced.

Official signing workflow: https://docs.flutter.dev/deployment/android#sign-the-app

## Publish after verification

Deploy the website code through the existing Dokploy application. Transfer the verified APK to a private staging path on the VPS, for example `/root/silvamang-ai-release.apk`. Then run on the VPS:

```sh
docker exec -u root sivamangai-sivamangai-c0m98v-app-1 mkdir -p /var/www/html/storage/app/releases
docker cp /root/silvamang-ai-release.apk sivamangai-sivamangai-c0m98v-app-1:/var/www/html/storage/app/releases/silvamang-ai.apk.new
docker exec -u root sivamangai-sivamangai-c0m98v-app-1 chmod 644 /var/www/html/storage/app/releases/silvamang-ai.apk.new
docker exec -u root sivamangai-sivamangai-c0m98v-app-1 mv /var/www/html/storage/app/releases/silvamang-ai.apk.new /var/www/html/storage/app/releases/silvamang-ai.apk
```

The final rename replaces only the downloadable APK. Back up the previous release before replacing it. No database or upload data is affected. The page detects the new file without a restart. Keep only verified release APKs at this path: the website checks file availability, not the Android signing certificate.

Open `/download` on a phone and confirm the APK installs. You can check response headers without downloading the whole file:

```sh
curl -I https://silvamangai.online/download/android
```

Expect HTTP 200, an APK content type and an attachment filename. Confirm file size/checksum after upload. iOS distribution is not configured by this page.
