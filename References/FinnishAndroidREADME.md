# 3000 Swedish Words for Android

The current Android update follows **iOS 1.0, build 29**. Development version **1.0.0-dev29** (code 2); application ID remains `com.linapps.swedish3000` to preserve installed Android progress.

Open this `Android` folder in Android Studio, let it sync, select `app` and your phone/emulator, then Run. Keep the adjacent `Resources` folder in place. Use the bundled JDK and Android SDK 36; minimum Android API 26.

The update aligns the Study, Words, detail and Progress screens and adds reminders, personal artwork/prompt histories, image import/export, prepared-pack import, help/privacy, and Google Play purchase integration. It also corrects remaining-card playback/shuffle, independent library search, multi-level undo and exact reminder routing.

See [the current parity review](docs/PARITY.md) and [verification](docs/VALIDATION.md) for evidence and outstanding device/store/release gates. Google Play product/public-key configuration is required before paid Android purchases can be tested; the default installation includes all basic words and the full free A set.

Build/check from this directory:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:assembleDebugAndroidTest
python3 tools/verify_content.py
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. On a personal phone, install with `adb install -r`; see the test-safety note in PARITY.md before running instrumentation. The historical notes below describe the initial implementation and are retained for context.

---

# Swedish Cards for Android — first implementation

Native Kotlin / Jetpack Compose port alongside iOS 0.21. Full feature parity is **in progress**. The shipping access provider is Free; payments and subscriptions are deferred. There is no fake purchase flow or release unlock switch.

Start with [the implementation roadmap](docs/ROADMAP.md), [feature checklist](docs/PARITY.md), and [test results](docs/VALIDATION.md).

## Build and run

1. Open this `Android` folder in Android Studio. Use the bundled JDK (17 or later; this project was built with Android Studio's JBR), and install Android SDK 36. The parent `Resources` directory must remain beside `Android`.
2. Let Gradle sync. The included Gradle 8.13 wrapper pins AGP 8.13.2 and Kotlin/Compose compiler 2.0.21.
3. Select `app` and an API 26+ emulator or Android device, then Run. A Swedish offline TTS voice must be installed for audio; silent study needs no speech engine or network.

From this folder:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest
python3 tools/verify_content.py
```

Set `JAVA_HOME` to Android Studio's bundled JDK if your default JDK is incompatible. Set `ANDROID_HOME` or your own untracked `local.properties` SDK path. The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. Build assets are generated from the original iOS resources; all 3,000 JPEGs and thumbnails are included. Allow roughly 3 GB for build intermediates. This is a large sideload development package; Play distribution and asset-delivery sizing are outstanding release work.

## Architecture

`domain` holds immutable word/filter/rating models, English dictionary sorting, access policy and the cancellable playback cycle. `data` holds a constructor-injected repository, transactional SQLite progress/event storage, settings, lazy Android speech and an observable entitlement interface. `StudyViewModel` owns a StateFlow and user actions; Compose collects it with lifecycle awareness. A small application container supplies dependencies. The UI has no SQL or store billing calls.

Canonical content loads on an IO dispatcher and is joined by stable IDs, preserving starter overrides and current sentence translations. Content is never written over learner progress. Ratings and history commit in one SQLite transaction; undo checks both the exact latest event and review count/date. Private progress/settings survive app updates; uninstall clears them. Backup is disabled until backup/privacy behavior has been designed. This port does not import an existing iPhone's learning history.

EntitlementRepository exposes Unknown/Free/Complete; AccessPolicy gates complete lessons and automatic selections. Replace the provider in SwedishApplication with a verified Play adapter later. Do not replace this with a saved premium Boolean. A lessons remain complete; B–Z basic pairs, manual ratings and word pronunciation stay available. The existing iOS product is a one-time non-consumable, not a subscription.

## Manual test pass

- Launch offline. See 3,000 vocabulary entries with all-word filters, and 211 when English letter A is selected. English X has no entries.
- Study: reveal/hide, English/Swedish direction, left/right swipe and rating buttons, undo, shuffle, empty-filter state and completed-selection restart.
- Words: search `ett äpple`, `apple`, or sentence text, combine letter/topic/status filters, practise list, open a detail and rate there. Check the study queue respects the new status.
- Kill/relaunch: ratings, review history, direction and playback settings remain; study queue deliberately restarts. Rotation retains ViewModel state and pauses audio.
- A lesson: image, memory hook, Swedish sentence and smaller English translation; zoom, pan, pinch/double-tap and back. B lesson: basic pair and Swedish word audio available, complete content hidden, no purchase button.
- Progress: known/learning/new counts total 3,000, daily/weekly history, goal 10 and Keep practising.
- Automatic A study: all-silent mode; each audio toggle; slow/natural/brisk; recall/post-audio timing; pause/resume replays prompt; previous/next skip without counting; completion/replay; Stop restores manual queue. Ratings/history must remain unchanged.
- Pause by tab switch, detail, filters, settings, Home/lock or audio-focus loss. Missing offline Swedish/English voices show a recoverable message. Retry after installing voices or disable audio.
- Test a small phone, tablet, Android 13+ and API 26, large text and TalkBack before release. Reminder and personal artwork tests will become available as those phases are implemented.
