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
  collection, **and is wired into the Runner target** — it has a file reference, sits in the Runner
  group and is listed under Build Phases → Copy Bundle Resources, so it actually ships. Confirm with
  `grep PrivacyInfo ios/Runner.xcodeproj/project.pbxproj` (four hits) after any Xcode project churn.
- **[done]** `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`, so App Store Connect stops
  asking the export-compliance question on every upload. Revisit only if custom cryptography is added.
- **[you]** A **publicly hosted privacy policy URL**. Both stores reject without one, and ads make
  it mandatory. GitHub Pages is fine.
- **[you]** Play **Data safety** form and Apple **App Privacy** — declare: notes stay on device;
  AdMob collects device/advertising identifiers for third-party advertising.

## 6b. Platform polish already handled

- **[done]** **No launch flash.** The Android `LaunchTheme` used `Theme.Light` with a white splash
  drawable, and the iOS `LaunchScreen.storyboard` had a white background — so a dark-only app
  flashed white on every cold start, worst on a light-mode device. Both now use `AppColors.bg`
  (`#06070F`), and `UIUserInterfaceStyle` is pinned to `Dark`.
- **[done]** **Predictive back** (`android:enableOnBackInvokedCallback="true"`), required behaviour
  on Android 13+ and expected by reviewers on 14+.
- **[done]** **Backup rules.** `backup_rules.xml` (Android 11 and below) and
  `data_extraction_rules.xml` (12+) both include `sharedpref`, so notes survive a restore or a
  phone-to-phone transfer. Without them the default is broader than it needs to be and undeclared.
- **[done]** **`AD_ID` permission declared explicitly** in `AndroidManifest.xml` rather than
  arriving silently through the AdMob manifest merge, so it is obvious when filling in Data safety.
  Shipping without ads? Uncomment the `tools:node="remove"` line — Play flags an app that declares
  `AD_ID` and never uses it.
- **[done]** **Notes are not lost when the app is backgrounded.** Writes are debounced; an
  `AppLifecycleListener` flushes anything pending on inactive/pause/hide/detach, and `dispose`
  writes rather than cancelling. Both platforms can kill a backgrounded process without warning.
- **[done]** **No crash artefacts in release.** `ErrorWidget.builder` renders `AppErrorView` instead
  of Flutter's grey (release) or red (debug) error box.
- **[done]** **Accessibility.** Every icon-only control has a label and a 44–48dp touch target,
  calendar cells announce their full date plus lunar day and holidays, checklist rows expose a
  checked state, note cards offer archive and more-actions as semantic actions (swipe and
  long-press are unreachable with a screen reader), and text scale is clamped to 0.85–1.35 so
  accessibility font sizes do not break the compact chrome.
- **[done]** **Reduce Motion** (iOS) / **Remove animations** (Android) stops the aurora repainting.

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

**Neither release build has been compiled.** The environment this was last worked in has the Flutter
SDK but no Android SDK and no Xcode, so `flutter build appbundle` and `flutter build ipa` have never
run. `flutter analyze` is clean and the full test suite passes, but that covers Dart only — it says
nothing about Gradle, R8, the manifest merge, CocoaPods or code signing.

Everything marked **[done]** above is configuration that has been read, edited and checked for
well-formedness (the plist parses, the XML parses, the `.pbxproj` sections and brace balance are
intact) — not configuration proven by a green build. Expect to fix a few Gradle/CocoaPods issues on
the first real run.

The `build-android` CI job builds a debug-signed bundle, which does exercise the release Gradle path
(R8, resource shrinking, manifest merge) even though it cannot exercise release signing.
