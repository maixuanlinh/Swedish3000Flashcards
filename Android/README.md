# 3000 Swedish Words for Android

## Production submission — 8 November 2026

Version **1.1.0 (3)** and the updated en-US listing were submitted together. Play Console confirmed **Changes in review**, with automated quick checks running. Managed publishing is off; the release targets a full rollout in the existing countries after approval. Eight current 1080×1920 phone screenshots replace the previous captures. Signing identity and existing Premium product IDs are preserved. See [release record](docs/PLAY-1.1.0-RELEASE.json) for bundle hashes and verification. Actual Play purchase/restore transactions were not repeated.

## Current checkpoint — 8 November 2026

Native Android **1.1.0-dev (3)** now follows **Swedish iOS 1.1.0 (8), incorporating Finnish iOS 1.1.0 (38)**. Study has the bottom playback toolbar, visible English translations and Topic-first filters. Words has nine topic cards and seven smaller core word groups, with shared progress by stable word ID. The exact current list resumes after reopening. Progress contains learning history and resume; Settings contains downloads, Premium reminders and inline website/support/privacy links.

Free automatically downloads only the 211 complete A-set lessons over any connection. Premium gets a remembered English download choice, Wi-Fi control and reminders every 30 minutes/hour/two hours or custom times, with sleep hours and recurring delivery. WorkManager downloads run off the UI thread and can be paused. Each language keeps its own package, billing configuration, database, reviewed content, hosting and visual theme.

See [iOS 1.1.0 parity and verification](docs/IOS-1.1.0-PARITY.md). The older notes below are retained as history; their Progress/settings navigation and version numbers describe earlier builds. **Version 1.1.0 (3) was submitted to Google Play production review on 8 November 2026. It is not yet verified live.**

Follow-up [UI and functional parity audit](docs/IOS-1.1.0-PARITY-AUDIT.md): inline filter cards, direct More menu, complete reminder choices, topic progress/search recovery and remembered offline preferences.

Read-only topic membership check: `python3 tools/verify_ios_topics.py`.

---

Native Kotlin/Jetpack Compose app updated from the current Finnish Android source on 2 November 2026. It keeps the same study, library, progress, reminders, artwork editing, purchase adapter, and offline-download flows. The interface and launcher icon use the Swedish iOS blue theme (#006AA7).

Application ID: `com.linapps.swedish3000`. Development version: `1.0-dev`, code 1. It installs alongside Finnish; its database remains `swedish-progress.db` with stable `sv-` learner IDs. Existing Swedish settings and progress are retained on compatible signed updates. No Finnish database, signing credential, or store identity is imported.

## Content and hosting

All 3,000 English headwords use the shared iOS Swedish translations, bilingual examples and reviewed artwork in `../Resources/`. The app uses the exact same prerecorded-media manifest and immutable packs as Swedish iOS, already hosted at `https://yki.essaykingapp.com/swedish3000/v1`. The 120 packs contain 3,000 illustrations and 8,675 distinct recordings for 9,000 playback positions. Swedish uses `sv-SE`, English `en-US`; Android speech voices are unnecessary.

Normal builds include only metadata and 21,716,927 bytes of starter media. Other lessons stream as needed. Progress and playback settings expose **Download for offline study**, with actual size, Wi-Fi-only control, pause/continue and removal. Removing downloads preserves progress and personal artwork. The shared pack format and media repository are inherited from the current Finnish Android app. Finnish hosting is untouched.

For future content changes, build shared resources and regenerate media using `../Tools/media/`. Upload new immutable packs into the Swedish directory before publishing the manifest; preserve old hosted packs for installed versions. Follow `../MediaDelivery/README.md`. No re-upload is needed when Android consumes the existing verified iOS packs.

## Build and verify

Open this folder in Android Studio, with its bundled JDK and Android SDK 36. Minimum API 26. Keep adjacent `Resources/` and `MediaDelivery/generated/assets/` available.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:assembleDebugAndroidTest
python3 tools/verify_content.py
```

Set `JAVA_HOME` and `ANDROID_HOME` for your installation if needed. The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. An explicit `-PmediaBaseUrl=` creates a fully offline development build using `../MediaDelivery/public/v1/`. Normal debug builds use the real free access policy (all basic word pairs and 211 complete A lessons); there is no fake paid unlock.

## Google Play preparation

The purchase adapter is present, but this new app requires its own Play application, active one-time product and public license key. Build a preparation bundle using `-PplayDistribution=true -PplayProductId=... -PplayLicenseKey=... -PreleaseVersionCode=1 -PreleaseVersionName=1.0 :app:bundleRelease`. Release builds require product and license values and use the Swedish media endpoint by default.

Signing reads only `SWEDISH_UPLOAD_STORE_FILE`, `SWEDISH_UPLOAD_KEY_ALIAS`, `SWEDISH_UPLOAD_STORE_PASSWORD`, and `SWEDISH_UPLOAD_KEY_PASSWORD`. Supply all four or none for an unsigned bundle. Do not use the historical Finnish signing helpers in `../References/`. No live Play purchase, Play publication, or signing setup is implied by a local build.

Read-only physical-device checks may run `SwedishSmokeTest` and `HostedMediaSmokeTest`. Broader inherited instrumentation may change study settings/ratings, request permissions, or download/remove media; run it on a disposable test installation. Never clear a learner's app data to run tests.

## Current internal Play release — 2 November 2026

Version **1.0 (2)** is Active and Available to internal testers, restricted to the owner-only tester list. Join at https://play.google.com/apps/internaltest/4701647930868433693. The app uses the YKI media endpoint directly. Premium product `swedish_complete` / `swedish-lifetime` is Active, priced at Finland €11.99, Sweden 129 SEK and US $10.99. The owner approved this price and internal rollout. Actual Play purchase/restore/refund checks and public-release declarations remain pending. See `release-preparation/README.md`.

### Production submission — 2 November 2026

Version 1.0 (2) was submitted with 11 changes for Google review. Console shows Changes in review, with quick checks running. Managed publishing is off: full rollout begins automatically after approval, in 177 named countries/regions plus rest of world. Premium remains €11.99 in Finland. The owner requested skipping further manual Play purchase/restore/refund tests. Five Google Play gift codes were provided privately for review; no code values are stored in source.
