# iOS build 29 → Android parity

Reference: current `Sources/`, `project.yml` (`MARKETING_VERSION=1.0`, `CURRENT_PROJECT_VERSION=29`) and `CommercialValidation/Screenshots/`. Reviewed 25 October 2026. The old Android baseline was iOS 0.21.

Android development version: **1.0.0-dev29**, version code **2**, installed identity `com.linapps.swedish3000`, display name **3000 Swedish Words**. iOS sources and canonical content were not changed.

| Area | Android implementation | Verification / remaining gate |
|---|---|---|
| Study layout | Compact filter/count/undo/play/options toolbar, full-height stacked card, centered prompt, answer/sentence/translation before illustration, bottom flip strip, matching rating colors and navigation | Device screenshots and interaction tests |
| Manual sessions | Remaining-card shuffle and automatic selection, multiple guarded undo operations, completion with saved count, shared status/letter/topic filters | ViewModel + actual SQLite tests |
| Library | Separate search, status pills, illustration/lock, result count, fixed bottom practice action, selected-word session | ViewModel + screen tests |
| Word detail | Illustration viewer, memory hook, example + translation, Swedish speech, New/Learning/Known controls, artwork editor | Screen tests; real TTS voice listening remains manual |
| Progress | Membership/reminder cards, Help, mastery ring, Learning/New tiles, seven-day bars, today's goal, Keep practising | Device screenshots; local-date calculation |
| Reminder selection | Default off, 1/2/4/custom times, pool/letter/language, image/sound switches, preview/sample | Planner tests: Helsinki DST, future-only dates, cycles, filters |
| Notification delivery | 14-day inexact local alarm queue, app-owned notification channels, boot/time/timezone/update rescheduling, refill invitation, permission handling, access-aware personal/bundled art | Live sample/tap and reboot/Doze checks are distinct from planner tests |
| Reminder destination | Exact card even when Known/outside current filters; temporary prompt language; no preference/rating mutation; cold-load inbox | ViewModel test; notification tap device gate |
| Artwork | Prompt copy/share/history, Photos and Files pickers, bounded 768px JPEG and 160px thumbnail, EXIF rotation, private revisions, original restore, zoom/pan | Real decoder/storage tests; user-picker/cloud-provider checks remain manual |
| Artwork interchange | iOS `swedish-cards-artwork-v1` per-word export; `swedish-cards-artwork-pack-v1` import, 500 records/150 MB, known-ID and duplicate checks, idempotence | Tests cover history/relaunch, invalid image protection, compatible packs and unknown-word rejection |
| Free/Premium | Basic 3,000 pairs + pronunciation/manual ratings; complete 211-word A set; gates for B–Z examples/art/auto/pack imports | Domain/access-revocation tests |
| Play purchases | Product lookup/local price, one-time flow, pending handling, signature-verified owned records, acknowledgement, restore/foreground refresh, signed proof for offline access | **Store configuration and Play test purchases still required.** No invented product/price/unlock flag |
| Help/privacy | Same support/privacy destinations, email support, device-only data explanation, independent-YKI notice | Screen test |
| Offline content | Existing 3,000 IDs/examples and 6,000 image files retained; no recompression of bundled artwork | Canonical asset verification |
| Release | Debug sideload app works independently of iOS | Release signing, Play asset-delivery sizing, tablet/API 26/TalkBack coverage still required |

## Platform differences

Android uses its native notification permission, channels, system image/file pickers, Google Play and text-to-speech engine. Inexact alarms can be delayed by Android battery management; this is explained in settings. Apple purchases do not transfer to Google Play. Native controls and font rendering differ between platforms.

## Purchase configuration

Set `playProductId` and `playLicenseKey` as Gradle properties for the actual Google Play one-time product and app licensing **public** key. Do not use an Apple product ID without creating/verifying the Android product. Without these properties the app stays Free, the complete A set works, and Premium explains purchase unavailability. Configure a Play test track and license testers to validate purchase/restore/pending/refund behavior. Server-side purchase verification and lifecycle notifications remain recommended release hardening.

## Test safety

On an existing physical phone, install with `adb install -r` and run the already-built instrumentation APK directly. Gradle's connected test runner configures automatic app uninstallation; do not use it against personal learning data without a backup and disabling that cleanup. The first locked-phone test attempt was stopped; app data was backed up locally before cleanup.
