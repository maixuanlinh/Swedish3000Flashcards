# 3000 Swedish Words — native iOS and Android

Local development project based on the native Finnish baseline `fa9932c`. The original SwiftUI iOS and Jetpack Compose Android layouts, study interactions, progress storage, artwork editor, and native reminders are retained. This project is separate from both the Finnish application and the React Native prototype.

GitHub destination: https://github.com/maixuanlinh/Swedish3000Flashcards . Push is intentionally deferred until the owner requests it.

## Current content

The source index contains 3,000 stable Oxford-based English entries copied from the Finnish app, including 211 A, 152 B, 292 C, 163 D and 162 E entries. All 980 A–E entries now have authored Swedish translations, example sentences, English translations, memory hooks, and reviewed images with embedded teaching text. Independent Swedish linguistic review is pending. `Content/status.json` records current coverage, `Content/artwork.json` records approved assets, and `Content/Generations/` preserves final generation prompts. F–Z entries remain pending and are excluded from study.

The complete A–E sets were verified on 2026-10-28: 11 iPhone simulator tests and 26 Android unit tests passed; Android debug build and lint passed. All 980 packaged images and shared content in both native apps match the source resource files by SHA-256, and master artwork hashes match generation provenance. Android device testing remains pending. See `Verification/de-sets-complete.json` for the current local verification record, with earlier A and B checkpoints retained. Nothing has been pushed to the Swedish remote.

Only authored words are bundled. F–Z entries remain pending in `Content/catalog.json`; they are excluded from study until their content is authored. `Content/status.json` reports real completion counts. The original headword source is the Finnish project's American Oxford-based list; a UK-edition reconciliation has not been done.

## Build

Run `node Tools/build_content.mjs` after content updates. Both native apps load the generated files in `Resources/`. Stable `sv-` IDs preserve progress as the catalog expands toward 3,000.

iOS: open `SwedishCards.xcodeproj` and use the `3000 Swedish Words` scheme. `3000 Swedish Words Local Purchases` uses a local StoreKit fixture only. `3000 Swedish Words Personal` enables private development access. Regenerate the project with `xcodegen generate` after changing `project.yml`. Requires Xcode and iOS 17+. Select your own signing team for physical devices.

Android: open `Android/` in Android Studio. Set `ANDROID_HOME` or untracked `Android/local.properties`, use JDK 17+, and run `./gradlew :app:assembleDebug :app:testDebugUnitTest`. The adjacent `Resources/` directory is required.

The independent app identifiers are `com.linapps.swedish3000` and `com.linapps.swedish3000.personal` (iOS personal build). They cannot overwrite the Finnish apps or their progress. Speech uses `sv-SE` for Swedish and `en-GB` for English. Store products, Swedish support/privacy pages, final icons, signing, and distribution are not configured for publication. The neutral S icon is temporary.

## Reference

The Finnish iOS app remains the design reference. `References/` holds inherited documentation and tests; historical Finnish release evidence is not proof of Swedish verification. The original baseline remains available in the separate Finnish repository.

## Verification

The local native baseline builds on both platforms. The iPhone 16 Pro simulator passed 11 tests including study/navigation and content/progress checks. Android passed 26 unit tests, built both the debug app and interface-test APK, and passed lint with 0 errors and 13 warnings. Android device testing is pending because no device or emulator was available. The Android APK's content hashes match iOS `Resources/` files. See `Verification/native-baseline.json` and `Verification/iPhone-study.png` for the exact recorded scope. No Swedish repository push has been performed.
