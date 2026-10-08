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

The page also explains how to update an existing installation. Android installation still requires the user's confirmation; the website does not detect the installed version or perform silent updates.

Optionally publish `storage/app/releases/release.json` alongside the verified APK to show its version and release notes:

```json
{
  "version": "1.1.0",
  "build": "2",
  "published_at": "2026-10-02",
  "notes": "Describe the changes included in this release."
}
```

These are example values: replace them with the actual APK version, build number, publication date and notes. Use strings for all fields. Update the metadata when replacing the APK so it describes the same release. Metadata is hidden when the APK is unavailable; missing or invalid metadata does not prevent a download. This file is informational, not a signature verification mechanism.

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

## Release 1.0.1 (build 2)

The October 8 release includes field transect numbers, survey location, category and Count-MG, structural measurement changes, and map improvements. The signed APK must be uploaded separately from a Git/Dokploy redeployment. A working `/download` page with a 404 from `/download/android` means there is no readable APK at the release path in the running application container.

Use the same release signing certificate as the previous public APK. The USB development installation is debug-signed and cannot be updated in place with this release-signed APK. Do not uninstall a development installation while it contains unsynced field data. This release does not add automatic in-app update detection; the download page remains a manual update channel.

Before publishing, deploy the matching backend and apply the October 8 ecological survey and transect-number migrations. Verify that observations and transects sync successfully.

## Release 1.0.2 (build 3)

Preserves ONNX Runtime Java classes and members in R8 release builds using `android/app/proguard-rules.pro`. Native inference looks these up by name; stripping or renaming them can crash identification. See https://onnxruntime.ai/docs/build/android.html. Also includes the transect attachment sheet navigation fix.

Before publishing, verify the signed APK and inspect `build/app/outputs/mapping/release/mapping.txt`: every original `ai.onnxruntime` class must retain its original name (compiler-generated synthetic lambdas may be renamed). Confirm identification on a device using the release APK; debug builds do not exercise R8.

## Release 1.0.3 (build 4)

Registration returns to Login without persisting an authenticated session. The capture screen adds Clear all photos below Continue. History provides confirmed deletion through the existing scan-record DELETE endpoint; failed requests leave the record visible. Deletion requires connectivity and also removes linked transect observation rows through the existing foreign key cascade.

Validation: scoped Flutter analysis, authentication/navigation tests, history deletion success/failure tests, and camera/gallery selection plus clearing multiple photos. Signed APK verification and public download checks are performed before publication.
