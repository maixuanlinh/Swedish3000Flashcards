# Android build-29 parity verification — 25 October 2026

Reference: iOS **1.0 (29)**, current Swift sources and commercial iPhone screenshots. Android **1.0.0-dev29 (2)**. This is a debug development build, not a Play release.

## Build and local checks

- `:app:assembleDebug :app:assembleDebugAndroidTest :app:testDebugUnitTest :app:lintDebug`: **BUILD SUCCESSFUL**. [Build log](parity-build29-build.log).
- **26 tests, zero failures**: 6 domain/playback, 9 ViewModel, 3 real SQLite/content, 5 reminder-planner, 3 real-decoder artwork/history/pack tests. JUnit results are in `app/build/test-results/testDebugUnitTest/`.
- Checks cover multi-level guarded undo, remaining-only playback/shuffle, independent library search and selected-word practice, detail reset to New, exact Known-word reminder routing with temporary language, access revocation, no auto-play ratings, Helsinki DST, shuffled reminder cycles, bounded image processing, invalid-image rollback, prompt/history persistence, compatible pack import/idempotence and unknown-ID rejection.
- Lint: **zero errors, 25 warnings**. Warnings cover dependency updates, platform ExifInterface, legacy backup/icon recommendations and Kotlin/Compose style suggestions. No lint baseline or suppressions were added.
- [Content audit](parity-build29-content.log): all 3,000 stable IDs/examples, 211 free A lessons and 6,000 bundled image files remain present. SHA-256 of every packaged canonical JSON, `artworkBriefs.json`, artwork manifest and JPEG matches the iOS resource source. No bundled images were regenerated or recompressed.

## Physical Samsung

Device: **Samsung SM-A546B, Android 14**. Installed by replacement with the same application ID and signing identity.

The five screen scenarios cover:

1. Reveal/hide prompt, Swedish answer, sentence and translation; open detail and illustration viewer.
2. Search the library, result count and practise exactly that selected word.
3. Swipe to Known and undo; verify stored review events and status return to the previous values.
4. Progress, reminder settings, Help/privacy and artwork editor navigation.
5. Silent automatic playback completion without rating/event writes; return to the manual card and retain it across rotation.

Result: **5 scenarios passed, zero failures**. [Final Samsung log](parity-build29-samsung-verified.log). The notification delivery/tap scenario runs separately in the disposable emulator so it does not change notification permissions on the personal phone. [Post-test data check](parity-build29-phone-data-check.json) confirms saved learning progress and review events were preserved, with database integrity `ok`.

Screenshots: [Samsung evidence](parity-build29-screenshots/samsung/parity-build29/). Visual inspection corrected a clipped illustration on the revealed study card. The answer image now fits its available space; short screens/large text can scroll.

## Emulator

Temporary API 34 Google APIs arm64 emulator, 1080×2340. The five screen scenarios passed. The independent notification test then passed **1 test, zero failures**, covering permission, scheduling, sample delivery, cold opening and warm reopening of the exact word, temporary prompt direction, one resumed app activity, unchanged saved direction and unchanged review events. [Final notification result](parity-build29-notification-verified.log).

The earlier combined emulator log (`parity-build29-emulator-verified.log`) retains a notification-test failure: an instrumentation process tried to send a background activity launch without the permission granted to an actual SystemUI notification tap. The final test emulates that authorized sender only inside the disposable emulator and uses lifecycle observation independently of Compose ActivityScenario. No production background-launch permission or lock-screen bypass was added.

## Data protection and test history

The initial Gradle connected test run failed because the Samsung was locked. Its automatic cleanup removed the app. Before cleanup, a local backup of the app's database/preferences/files was captured. The app was reinstalled and the backup restored; the restored learning database matched the backup byte-for-byte and passed SQLite `integrity_check`. Further physical-phone tests ran directly through the installed instrumentation package, which does not uninstall the app. Swipe tests undo their own events, playback tests restore their settings, and notification-permission changes are confined to the disposable emulator.

Earlier failed logs are retained: locked-screen/test-selector failures, transitional screenshots and the notification activity-lifecycle issue. Use the **final** logs/screenshots for the delivered build. Earlier 19 October validation remains in `validation.json` and describes the original iOS 0.21-based Android implementation.

## Remaining release/manual gates

- Configure the actual Google Play one-time product and app licensing public key; validate real Play test-track purchase/restore, pending, cancellation/refund and offline ownership. No actual payment was made and no invented price/product was used. Server-side verification and purchase lifecycle notifications remain release hardening.
- Listen to Swedish/English pronunciation with installed offline voices; calls/headsets, missing-voice recovery, real-world notification sound/Doze/reboot/timezone behavior and long-duration schedules still need manual hardware coverage.
- Exercise actual Photos/Files providers and cancellation, large/invalid images, sharing/export destinations, TalkBack, very large font settings, API 26 and tablets. Repository/decoder tests do not establish all provider behavior.
- Release signing, Android App Bundle/asset delivery and store-size acceptance remain separate. The debug package includes roughly 574 MiB of offline content/runtime; it is intended for sideload testing.

Platform behavior such as font rendering, system pickers, speech voices and Android's battery-delayed reminders cannot be pixel-identical to iOS. See [the parity review](PARITY.md) for the implementation contract and store configuration.
