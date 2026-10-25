# Android implementation roadmap

Historical planning baseline. The build-29 implementation and verification status are now recorded in [PARITY.md](PARITY.md) and [VALIDATION.md](VALIDATION.md); the future-tense items below describe the original plan.

Baseline: inspected iOS 0.21, `Sources/`, `Tests/`, `UITests/`, README and canonical Resources on 19 October 2026. Android is a separate native app; iOS files and learner data remain unchanged. This document was written before implementation. Current delivery status is in PARITY.md.

## 1. Establish the content and behavior contract (P0)
- Preserve all 3,000 stable `sv-…` IDs and source IDs. Merge starter topic/edited word metadata with catalog entries and current examples exactly as StudyStore.readSeeds does.
- English dictionary order strips punctuation, accents and parenthesized senses; source ID breaks ties. Preserve Swedish ä/ö, sentence translations, original illustration prompts and memory hooks.
- Use existing JPEGs/thumbnails directly as build assets without recompression or maintaining a second 594 MB source copy. Check every reference before packaging.
- Acceptance: 3,000 unique word IDs, complete bilingual examples and image pairs, 211 English A entries; no source resource changes.

## 2. Build the offline foundation (P0)
- Kotlin, Jetpack Compose/Material 3, single activity, ViewModel + immutable StateFlow UI state, constructor injection, repository boundary and local persistence. Min SDK 26, target/compile SDK 36.
- Keep domain filtering, ordering and access policy independent of Android for focused tests. Load and decode assets off the main thread. Store ratings/review history separately from bundled content so upgrades preserve learning.
- Acceptance: debug APK compiles, cold start works offline, load failure has retry, rotation keeps the study session, persistence survives process restart.

## 3. Complete manual learning (P0)
- Study / Words / Progress navigation. Tap-to-flip, left Learning/right Known swipe, buttons, guarded undo, English/Swedish direction, shuffle, end-of-session restart.
- Shared search (English, Swedish, sentence), status / English A–Z / topic filters and counts, practise current results, word detail and detail ratings.
- Full illustration, memory hook, Swedish example plus muted English subtitle; hide answers on prompt. Accessible text remains separate from text embedded in art.
- Counts, mastery fraction, seven-day review activity, today's goal of 10, Keep practising routing.
- Acceptance: rating persists and removes cards from applicable filtered queue; undo removes its exact history event; a later rating prevents stale undo; detail ratings reconcile with study.

## 4. Speech and automatic playback (P0)
- Lazy Android TextToSpeech using installed Swedish/English voices. Missing/offline voice recovery; no speech at launch.
- Persist recall and post-audio pauses 1–15 seconds, independent prompt/answer/sentence audio toggles and Slow/Natural/Brisk speed.
- Cancellable engine awaits utterance completion, recall pause, reveal, answer and sentence completion, post-audio pause, then advance. Distinct completed count excludes skipped cards. No automatic ratings/history.
- Previous / pause / resume / next / stop; retain untouched manual queue. Pause on tabs, details, filters, settings, background, lock and audio interruptions. Resume restarts prompt; completion can replay.
- Acceptance: fake-clock/fake-speech sequencing tests, interruption/cancellation tests and device audio checks; all-silent mode works without a voice.

## 5. Local reminders (P0, before feature-parity release)
- Defaults off; 1/2/4 or up to four custom local times, pool/status/letter filters, Swedish/English/bilingual prompt, uppercase target, optional sound/artwork and sample.
- Android notification channel + contextual POST_NOTIFICATIONS request on Android 13+. Schedule local delivery using AlarmManager (inexact unless a justified exact-alarm use case is approved); disclose OS timing limits. No push server.
- Fourteen-day shuffled queue, refresh invitation, refill on foreground; boot/timezone/time change receiver. Handle permission denial, disabled channel, Doze and empty pools.
- Immutable PendingIntent routes exact word ID after cold load regardless of filters/known state; temporary language override never changes saved direction or ratings.
- Artwork chooses personal then bundled, follows access changes, falls back to text; remove only this app's scheduled/delivered reminders on disable/access loss.
- Acceptance: closed-app delivery/tap, reboot, DST/timezone, denial/re-enable, text/image fallbacks and no-progress-change tests on device.

## 6. Personal artwork tools (P1, before feature-parity release)
- Prompt editing/copy/history, system photo and document pickers, bounded decoding/downsample to 768px JPEG + 160px thumb, private files and transactional revision metadata.
- Active revision/history, restore original, fullscreen pinch/double-tap zoom, per-word JSON export and iOS-compatible prepared-pack import (500 words / 150 MB), idempotence and unknown-ID rejection.
- Preserve iOS pack schema and exact chosen-revision prompt. File size/dimension guards; failed imports must keep previous active image. Never move originals.
- Acceptance: picker cancellation, large/invalid image, pack limits, history restore, process restart, export round-trip and missing-file fallback tests.

## 7. Close platform and release gaps (P0)
- Small phone/tablet, rotation/process death, large text, TalkBack, touch targets, contrast, system back, offline startup, image memory and navigation benchmarks.
- Port behavioral scenarios from all four iOS test files and both UI suites; validate against the Preview screenshots without copying iOS-only controls.
- Measure signed release size. Existing artwork alone is ~594 MB; investigate Android App Bundle/install-time asset delivery and Play distribution limits before publishing. Do not silently drop/compress images. Set application ID, signing, backup/export policy and versioning deliberately.
- Acceptance: all non-payment rows in PARITY.md device-verified; no known data-loss or lifecycle failures. Cross-platform progress sync and spaced repetition are not iOS features and are not introduced here.

## 8. Store payments (deferred, P2)
- iOS uses one non-consumable purchase, not subscriptions. Start with the equivalent Play one-time product; subscriptions only if product requirements change.
- Inject EntitlementRepository with observable Unknown / Free / Complete access. AccessPolicy alone gates complete lessons, sentence/artwork features, packs and auto playback. Basic pairs, manual ratings, word speech, search, progress and text reminders always remain free; A lessons always complete.
- Initial Android provider resolves Free and exposes no purchase/restore button or fake price. Never persist a user-editable premium Boolean. Test Complete using injected fakes only.
- Later Play adapter verifies ownership, handles pending/cancelled/refunded/revoked states, acknowledges purchases, refreshes on foreground and publishes changes. UI/content/storage do not depend on BillingClient. Offline verified access and backend verification strategy need a deliberate design.
- Access loss must stop newly disallowed playback, hide paid lesson details, rebuild pending reminders and clear delivered paid images. Test fresh install restore, offline ownership and refund. Store purchases do not transfer automatically from Apple.

Architecture reference: https://developer.android.com/topic/architecture/recommendations and https://developer.android.com/develop/ui/compose/compiler. Use pinned compatible dependencies, not floating versions.
