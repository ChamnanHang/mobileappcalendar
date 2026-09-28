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

- **[done]** **No launch flash in either mode.** The app follows the system light/dark setting, so
  the launch screens do too: Android has a light `LaunchTheme` in `values/` and a dark one in
  `values-night/`, each painting `@color/app_background` (white / `#0F0F12`); iOS paints the
  `LaunchBackground` colour set, which has a dark appearance. Both match the first Flutter frame.
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
- **[done]** **Reduce Motion** (iOS) / **Remove animations** (Android) is honoured; there is no
  continuously animating background left to stop — an idle screen draws no frames.

## 7. Store listing assets

- **[you]** Screenshots: iPhone 6.7" and 6.5"; Android phone (min 2). The calendar and the notes
  grid both look good in light and dark — `flutter run -d chrome` at a phone viewport is an easy way
  to capture them.
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

**Android release now builds; iOS is building in CI for the first time.**

The `build-android` job compiles a release APK and app bundle, so R8, resource shrinking,
`proguard-rules.pro` and the manifest merge are all exercised and passing — release APK 52.9 MB,
bundle 54.4 MB. (The APK is universal, carrying every ABI; Play splits the bundle per device, so
what users download is far smaller.)

The `build-ios` job runs on a macOS runner and compiles for the simulator — **passing**, the first
time the iOS side has ever been compiled. It covers the Dart build, CocoaPods resolution and
linking, and asserts on the built bundle rather than on the repo: `PrivacyInfo.xcprivacy` is inside
`Runner.app` and well-formed, the Info.plist carries `ITSAppUsesNonExemptEncryption=false` and no
`UIUserInterfaceStyle` pin, and the `LaunchBackground` colour is compiled into `Assets.car`. That retires the warning this file used to carry about the
privacy manifest sitting outside the Xcode target — it is now proven bundled by a real build, not
by reading the `.pbxproj`.

**Still not exercised anywhere: code signing.** Neither the Android upload key nor an iOS
distribution certificate is in the repo, so `flutter build ipa` and a Play-acceptable signed bundle
have never been produced. Expect the first signed build to need a few attempts.

Everything marked **[done]** above is configuration that has been read, edited and checked for
well-formedness (the plist parses, the XML parses, the `.pbxproj` sections and brace balance are
intact) — not configuration proven by a green build. Expect to fix a few Gradle/CocoaPods issues on
the first real run.

The `build-android` CI job now builds a **release** APK and app bundle, which does exercise R8,
resource shrinking and `proguard-rules.pro` — an earlier version of this job built only a debug
bundle and claimed otherwise, which was wrong: minify and shrinking are configured on the release
buildType alone. Release *signing* is still not exercised, because the keystore is not in the repo;
without `android/key.properties` the build falls back to the debug key.

Both APKs and the bundle upload as a run artifact named `noted-android`, downloadable from the
workflow run's summary page — so the app can be installed on an emulator or a phone
(`adb install -r app-debug.apk`) without a local Android SDK.
