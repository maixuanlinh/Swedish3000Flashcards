# Follow-up UI and functional parity audit

8 November 2026. Reference: **Swedish iOS 1.1.0 (8), using Finnish iOS 1.1.0 (38) as its baseline**. Native Android 1.1.0-dev (3). This audit supersedes any implication that the earlier existence/data checks established complete visual parity.

## Reference and method

Compared each Android screen and domain flow with the released iOS source in the same app's `Sources/`, including `EnglishAlphabet.swift`, `WordLibraryView.swift`, `StudyView.swift`, `AutoStudyOptions.swift`, `ProgressViewScreen.swift`, `SupportView.swift`, `WordReminderSettingsView.swift`, `WordReminderPlan.swift`, `OfflineStudyView.swift` and the download/session services. Visually inspected the saved iOS release filter screenshot and the new Android selected-card screenshot. Android screen checks run on the disposable API 34 ARM64 phone emulator in portrait and landscape; focused checks also use system text scale 1.5.

The initial review missed the extra Topic dropdown interaction. This follow-up checks control availability, direct selection, selected state, counts, Cancel/Reset/Apply behavior and persisted results, rather than treating topic-data equality as UI equivalence.

## Comparison and corrections

| Area | Released iOS behavior | Android correction / verification |
| --- | --- | --- |
| Filter topics | All 16 topic/group cards inline, after status and before letters | Removed dropdown. Reusable adaptive card grid, native/English names, shared known count/progress, selected outline and check. All topics has a direct clear action. |
| Filter transaction | Cancel discards draft; Reset clears status/topic/letter; Show applies combined filter | Cancel/centered title/Reset header; sticky Show count. Tests exercise cancellation without bookmark/queue changes, reset, all cards, topic + letter, searched candidate counts and recreation. |
| Library | Scrollable header/search, nine themes/seven groups, topic detail/progress, other-topic labels | Restored topic header known/learning counts and progress, word-row topic labels, back-to-topics header, full-page scrolling and native theme progress bars. |
| Empty/search/back | Clear filters recovers results; clearing search can restore topic browsing; Back clears old library restrictions | Added empty-state action and fixed browsing/search state. Case/accent-insensitive matching uses English/native headwords and native examples like iOS. English example translations are displayed, but do not independently match search. Bookmark is preserved until Practice. |
| Study | Topic/letter/selection-specific title; bottom play controls; minimal More menu | Aligned title rules, filled play button, distinct playback sliders and main Settings gear. Replaced full-page More panel with the two direct direction/shuffle menu actions. No duplicated playback or rating controls. English example stays visible after reveal. |
| Playback | Pace 1–15 seconds, three reading switches, voice speeds, explicit return to manual | Existing native playback/recordings retained and exercised. Removed extra offline-download entry absent from the iOS playback form; aligned manual-return text. Playback never changes word ratings; rotation preserves the current word. |
| Progress | Saved ordered session, first five learning words, practise all learning words, shared totals | Aligned preview size and learning button. Fixed Keep practising so the last letter/topic cannot silently exclude other learning words. Resume/recreate and shared-ID progress checks pass. Finnish progress accent corrected to its own iOS theme. |
| Settings | Membership, downloads, Premium reminder row, website/report/privacy inline | Aligned row order; added the visible Premium reminder label. Own branding, support URLs and purchase restoration retained. |
| Reminder choices | 30/60/120/180/240 minutes; once/twice/four times daily; custom up to 48 times | Added missing 3-hour, 4-hour and daily preset options. Editing a preset makes it custom; Add time follows iOS spacing. Sleep hours, enable/permission, preview/sample and saved preferences retained. |
| Notification delivery | Exact word/direction; no rating on open; sleep suppresses scheduled notifications | Existing cold/warm tap regression retained. New emulator tests make a fixture alarm due, verify real delivery and schedule replenishment, drop a delivery delayed into sleep, and cancel delivery on Premium revocation. |
| Free offline | 211 complete A-set lessons auto-download on any network | Asset-range and durable-cache tests retain A-only boundaries; full download/reminder requests are rejected for Free. Study stays usable while background work runs. |
| Premium offline | Full collection size, one-time English choice, remembered Wi-Fi preference, pause/resume/remove | Display total follows entitlement even if A-set work is running. Wi-Fi preference now persists independently of automatic Free downloads; complete download can replace Free work directly. Choice/Later, full-size label, preference persistence and controls are exercised. |
| Content/artwork/purchases | Own reviewed content, stable IDs and restored customer access | Exact taxonomy and packaged-resource hashes checked against each app's own iOS resources. Database, artwork repository and Play Billing adapter are unchanged from task backups. Existing unit/media/editor checks retained. |

## Verified results

- 56 unit tests, zero failures/errors.
- 19 Free UI/function scenarios and 7 Premium/notification scenarios, zero failures.
- 3 focused interaction scenarios repeated at 150% system text size, zero failures. Text scale restored to 1.0 afterward.
- Final build and lint pass (0 errors, 19 warnings). Exact topic mappings and packaged content/media hashes pass.

## Evidence and boundaries

Task-workspace `preview/android-1.1.0/` contains final APKs/source checkpoints, screenshots, preserved-source hashes and machine-readable test results. `verification/` contains build and emulator logs. `tools/verify_ios_topics.py` verifies exact memberships/labels; `tools/verify_content.py` verifies packaged reviewed content and media.

The earlier visible-emulator rotation run waited indefinitely in Espresso's next-frame synchronization. The isolated rotation scenario passed with the background renderer, followed by the complete suites. This is recorded as an interrupted renderer/test run, not a successful full run.

The subsequent visible software-rendered emulator produced an ANR whose trace explicitly said “Buffer processing hung up due to stuck fence. Indicates GPU hang.” The evidence is retained as `verification/swedish-visible-software-gpu-anr.txt`. Switching the visible emulator to `-gpu host` selects Apple M2 Pro hardware graphics. Its five-scenario recheck passed four scenarios and reported one Compose `SnapshotStateObserver` drawing-thread exception; that scenario then passed in an isolated retry. Both logs are retained rather than counting the failed run as green. The complete headless feature suites and large-text suites passed independently. The normal app is reopened without the instrumentation fixture for manual review. Android's graphics modes are documented in [Configure hardware acceleration](https://developer.android.com/studio/run/emulator-acceleration).

Premium is simulated only in the test APK. The main APK retains actual Play Billing. A real licensed Play purchase/restore and a signed upgrade of an existing Play installation still require a Google Play test track; neither is claimed by emulator tests. Android native dialogs/fonts and OS background alarm timing follow Android conventions; this audit does not claim pixel identity or exact-time delivery across operating systems. No iOS source, reviewed vocabulary, store identity, credential or learner database is replaced. No Google Play upload or Git push is performed.
