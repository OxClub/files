# Ox Files

A fast, private file manager for Android and Amazon Fire tablets, by **OxClub**.

- Package name: `com.oxclub.oxfiles`
- App name: **Ox Files**
- No ads, no analytics, no internet permission. Files never leave the device.
- No Google Play Services dependency (works on Fire OS).

## Features

- Home screen with internal storage and SD card / USB cards (used / total space)
- Categories: Images, Videos, Audio, Documents, Archives, APKs (with file counts)
- Quick access: Downloads, Camera, Pictures, Documents, Movies, Music
- Recent files and global search
- Folder browser: sort, hidden files, new folder, rename, copy, move, delete
- ZIP create, extract ZIP / TAR / TAR.GZ / TAR.BZ2 (RAR and 7z can be listed but not extracted)
- Light and dark theme (follows system)

## Project layout

```
.github/workflows/build.yml   CI: builds, signs and publishes the APK
app_src/pubspec.yaml          dependencies + icon config
app_src/lib/                  Dart source (main, home, browser, category, common)
app_src/assets/icon/          launcher icon (0x folder logo)
store_assets/                 icon_512.png, icon_114.png for the Amazon listing
```

The Android project itself is generated in CI with `flutter create --org com.oxclub --project-name oxfiles`,
so the package name is `com.oxclub.oxfiles`. The workflow also sets the label to "Ox Files"
and adds the storage permissions to the manifest.

## Build (GitHub Actions)

Push to `main` (or run the workflow manually from the Actions tab). The workflow builds a
release APK, signs it, uploads it as an artifact and creates a GitHub Release
`v1.0.<run number>`. The run number is also used as `versionCode`, so it always increases
(Amazon requires this for updates).

## Release signing (required for Amazon)

1. Create a keystore once (Termux: `pkg install openjdk-17`):

   ```
   keytool -genkeypair -v -keystore oxfiles.jks -alias oxfiles \
     -keyalg RSA -keysize 2048 -validity 10000
   base64 -w0 oxfiles.jks > ks.txt
   ```

2. In the GitHub repo go to Settings > Secrets and variables > Actions and add:

   | Secret | Value |
   |---|---|
   | `KEYSTORE_BASE64` | contents of `ks.txt` |
   | `KEYSTORE_PASSWORD` | the keystore password |
   | `KEY_ALIAS` | `oxfiles` |
   | `KEY_PASSWORD` | only if different from the keystore password |

3. **Back up `oxfiles.jks` and its password somewhere safe.** If you lose it you cannot update the app
   with the same signature. Never commit it to the repo.

Without these secrets the APK is debug-signed: fine for testing, not for the store.

## Amazon Appstore checklist

- [ ] Signed APK from a GitHub Release (see above). Amazon may re-sign it with its own key; keep your keystore anyway.
- [ ] Icons: `store_assets/icon_512.png` (large) and `icon_114.png` (small).
- [ ] Screenshots: take from a Fire tablet or emulator (landscape and portrait), per Amazon's size rules.
- [ ] Privacy policy URL (required). Say clearly: no data collected, no network access, files stay on device.
- [ ] Content rating questionnaire and app category (Utilities / Productivity).
- [ ] Permissions justification. The app uses `MANAGE_EXTERNAL_STORAGE` because a file manager must access all files.
      Explain this in the submission notes. `REQUEST_INSTALL_PACKAGES` is only for opening APK files
      from the APKs category; remove that line in `build.yml` if reviewers object.
- [ ] Test on a real Fire tablet (Fire OS 7/8) before submitting: browse, extract ZIP, copy/move, SD card.
- [ ] Bump nothing manually: version code = GitHub run number.

## Local development

```
flutter create --project-name oxfiles --org com.oxclub --platforms android app
cp app_src/pubspec.yaml app/pubspec.yaml
rm -rf app/lib && cp -r app_src/lib app/lib && cp -r app_src/assets app/assets
cd app && flutter pub get && dart run flutter_launcher_icons && flutter run
```

Remember to add the storage permissions to `AndroidManifest.xml` as in `build.yml`.

## Known limitations

- RAR / 7z extraction is not supported.
- Storage usage bar relies on the `df` command; if a device blocks it the bar is simply hidden.
- Category scan reads the whole storage once per launch; very large storage may take a few seconds.

## License

Copyright (c) OxClub. All rights reserved.
