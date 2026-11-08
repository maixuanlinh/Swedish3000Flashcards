# Android / iOS 1.1.0 parity

Checkpoint: 8 November 2026. Benchmark: **Swedish iOS 1.1.0 (8), incorporating Finnish iOS 1.1.0 (38)**. Android development build: **1.1.0-dev (3)**, existing application identity.

See [the follow-up screen and interaction audit](IOS-1.1.0-PARITY-AUDIT.md) for the inline-filter correction and expanded UI/function comparison.

## Implemented behavior

- Nine language-specific themes plus seven core word groups, every core collection at most 300 words. Exact iOS headword membership and native labels are checked by `tools/verify_ios_topics.py`. Reviewed vocabulary/artwork/media are reused without rewriting content. Words can belong to multiple topics; ratings remain keyed by the existing stable word ID.
- Ordered remaining study list, filter, selected-word state, initial count and prompt direction persist in existing preferences. Library search does not replace the active learning list until Practice is chosen. Notification sessions do not replace it. Progress offers resume and learning-word access.
- Four bottom tabs; Study title/count/filters at top, undo/previous, play/pause, next, playback settings and More below the flashcard. More contains direction and shuffle; no duplicated playback action or rating buttons. English example translations remain visible after reveal. Topic precedes English initial in Filters.
- Settings contains membership/restore, downloads, reminders, website, one email report/feedback action and inline privacy/about. Progress contains learning information.
- Free automatically downloads durable images and recordings for exactly 211 A-set lessons over any connection. Asset-level verified byte ranges prevent B–Z pack content entering the Free download. Free can pause/resume/remove. Durable Free files survive temporary cache loss.
- Premium gets the English one-time download choice (Wi-Fi / now / later), full collection downloads and resumable WorkManager jobs. Network/disk operations run on IO dispatchers and do not block studying. Pausing/removing is remembered rather than immediately auto-starting again.
- Premium reminders support 30-minute, hourly, two-hour and custom schedules, editable sleep hours and local sample notifications. One next inexact Android alarm is scheduled and replenished after delivery indefinitely; legacy schedules migrate. Delivery checks entitlement, current eligibility and sleep hours. Android power management can delay inexact alarms; notification permission is required.

## Preservation and verification

- `assembleDebug`, `testDebugUnitTest`, `assembleDebugAndroidTest` and `lintDebug` succeed. **56 unit tests pass**, no failures/errors. Lint reports zero errors and 19 non-blocking warnings, including existing artwork EXIF and Compose style warnings.
- Android 14 / API 34 ARM64 disposable emulator, 1080×2400 phone. New Free scenarios cover automatic A-only downloads, live study during downloads, topics/core groups, ordered session/resume, footer/filter order, translations and Settings gates. Premium scenarios cover English prompt/Later persistence, 30-minute/sleep settings and a real sample local notification. Notification regression checks exact word/direction on cold and warm taps without changing learning history. Existing media/study scenarios check hosted artwork and both recorded languages, offline controls, reveal/detail, swipe/undo, search/Practice, playback completion and rotation.
- Emulator Premium is injected **only by androidTest APK classes**. The main APK keeps the real Play Billing adapter. No purchase was made and no customer entitlement was altered.
- Source/content SHA-256 checks match the pre-edit snapshots. `StudyRepository.kt`, `ArtworkRepository.kt` and `PlayEntitlements.kt` are byte-identical to the backups, preserving database, imported-artwork handling and purchase verification. Own package/language/media URL and theme are retained.
- `tools/verify_content.py` checks all 3,000 stable IDs, examples/artwork, 211 Free lessons, packaged metadata and bundled pack hashes against the reviewed iOS resources.

Evidence is saved in the task workspace under `preview/android-1.1.0/` (test logs, APKs, screenshots, preservation report and source patch). The full pre-edit Android source remains under `.backups/` in that workspace.

## Release boundary

This is a local development checkpoint, not a Google Play submission. Actual purchase/restore and a signed upgrade of an existing Play installation still need a licensed Google Play test-track check. Emulator Premium validates behavior, not a real Play transaction. Signing keys/product IDs were not replaced. Use a Play test track for customer upgrade testing; do not uninstall a learner's app or erase progress to install a differently signed debug APK. Build code 3 is the local default; confirm the latest Play code before a future upload.

Reproduce native checks with Android Studio's bundled JDK and the installed Android SDK:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:assembleDebugAndroidTest :app:lintDebug --offline
python3 tools/verify_content.py
python3 tools/verify_ios_topics.py
```

Instrumentation mutates only disposable test data. Run Free tests without fixture arguments; Premium tests use `-e premium true -e resetPrompt true` with the test-only `ParityTestRunner`. Never run destructive/reset test preparation on a personal device.
