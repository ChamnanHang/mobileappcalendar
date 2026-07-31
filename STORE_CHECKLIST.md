# Shipping Noted to the App Store and Play Store

Status of each item is marked **[done]** (already in the repo) or **[you]** (needs your account,
password, or a manual decision — I can't do these).

---

## 1. Identity — decide once, never changeable after the first upload

- **[done]** Bundle ID / applicationId: `com.khmercalendar.noted` (Android `build.gradle.kts`,
  iOS `project.pbxproj`, Kotlin package moved to match).
- **[done]** Display name: **Noted** on both platforms.
- **[done]** App icon generated from `assets/branding/app_icon.png` into every Android and iOS
  size, including an Android adaptive icon. Regenerate with `dart run flutter_launcher_icons`.
- **[you]** App Store name must be globally unique. "Noted" is almost certainly taken — have a
  fallback ready (e.g. "Noted — Khmer Calendar").

## 2. Accounts

- **[you]** Apple Developer Program — **$99/year**. Required to ship to the App Store at all.
- **[you]** Google Play Console — **$25 one-time**. New personal accounts must also complete
  identity verification, and Google requires **12 testers for 14 days** before a personal account
  can go to production. Start that early; it is the longest lead time in this list.
- **[you]** AdMob account, linked to the Play/App Store listing.

## 3. Toolchain (currently missing on this Mac)

`flutter doctor` reports both as incomplete:

- **[you]** Xcode from the App Store (~15 GB), then:
  ```bash
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  ```
  ```bash
  sudo xcodebuild -runFirstLaunch
  ```
- **[you]** CocoaPods: `brew install cocoapods`
- **[you]** Android Studio + SDK for Android builds.

## 4. Android release signing

- **[done]** `build.gradle.kts` reads signing from `android/key.properties`, falling back to the
  debug key when absent. **Play rejects debug-signed uploads**, so this file is mandatory.
- **[done]** `key.properties`, `*.jks` and `*.keystore` are git-ignored; a template lives at
  `android/key.properties.example`.
- **[done]** R8 minify + resource shrinking enabled, with ProGuard rules for the ads SDK.
- **[you]** Generate the keystore and **back it up somewhere safe** — lose it and you can never
  update the app under the same listing:
  ```bash
  keytool -genkey -v -keystore ~/noted-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- **[you]** Copy `android/key.properties.example` → `android/key.properties` and fill it in.

## 5. Ads (AdMob)

- **[done]** `google_mobile_ads` wired in, banner pinned above the nav bar on both tabs.
- **[done]** Ads are **off by default** and compiled out of web/desktop/test runs, so nothing
  touches the network until you opt in.
- **[done]** Placeholder AdMob app IDs in `AndroidManifest.xml` and `Info.plist`.
- **[you]** Replace **all four** placeholder IDs with your real ones. Google's test IDs must never
  ship, and real ads must never be clicked by you — both get accounts banned.
  ```bash
  flutter build appbundle --dart-define=ADS_ENABLED=true \
    --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY
  ```
  Also update `com.google.android.gms.ads.APPLICATION_ID` and `GADApplicationIdentifier`.
- **[you]** iOS: ads require an **App Tracking Transparency** prompt before requesting a tracking
  identifier. Add `NSUserTrackingUsageDescription` to `Info.plist` and call the ATT API, or
  configure AdMob for non-personalised ads only.
- **[you]** Add a **UMP / consent** flow if you serve users in the EEA or UK.

## 6. Privacy — required by both stores

- **[done]** `ios/Runner/PrivacyInfo.xcprivacy` declares UserDefaults use and AdMob's device-ID
  collection. ⚠️ **Add it to the Runner target in Xcode** (drag into the project, confirm it appears
  under Build Phases → Copy Bundle Resources) — a file on disk alone is not bundled.
- **[you]** A **publicly hosted privacy policy URL**. Both stores reject without one, and ads make
  it mandatory. GitHub Pages is fine.
- **[you]** Play **Data safety** form and Apple **App Privacy** — declare: notes stay on device;
  AdMob collects device/advertising identifiers for third-party advertising.

## 7. Store listing assets

- **[you]** Screenshots: iPhone 6.7" and 6.5"; Android phone (min 2). The calendar and the notes
  grid both look good — `flutter run -d chrome` at a phone viewport is an easy way to capture them.
- **[you]** Play feature graphic 1024×500, short (80 char) and full (4000 char) descriptions.
- **[you]** Content rating questionnaire, target audience, and a support contact.

## 8. Build commands

```bash
flutter build appbundle --release
```

```bash
flutter build ipa --release
```

Bump `version:` in `pubspec.yaml` before each upload (`1.0.0+1` → `1.0.1+2`); Play rejects a
reused build number.

---

## Not yet verified

Neither release build has been compiled — this Mac has no Xcode and no Android SDK, so
`flutter build appbundle` and `flutter build ipa` have never run. Everything above is configuration
review, not a successful build. Expect to fix a few Gradle/CocoaPods issues on first run.
