# 3000 Swedish Words — native iOS and Android

## iOS 1.1.0 (8) submitted for review

Submitted on 8 November 2026 at 01:34 EET, with automatic release after Apple approval. App Store Connect status: **Waiting for Review**. The update follows Finnish 1.1.0 (38). See [release verification](Verification/Release-1.1.0-8/README.md) for the exact package/source hashes, passing final phone checks, release copy and submission proof. This supersedes the marketing-only 1.0.1 (7) draft.


## Finnish 1.1.0 parity update

The native iOS app now follows Finnish **1.1.0 (38)**, with Swedish customer version **1.1.0 (7)**. Topic cards, saved sessions, separate Settings, reminders and background downloads are ported. Swedish content, identities, progress models and existing Premium access are retained. See [the parity checkpoint](Verification/Parity-1.1.0/README.md) for verification, screenshots and known test-tool limitations. Changes remain local; Android was not changed by this port.


Local development project based on the native Finnish baseline `fa9932c`. The original SwiftUI iOS and Jetpack Compose Android layouts, study interactions, progress storage, artwork editor, and native reminders are retained. This project is separate from both the Finnish application and the React Native prototype.

GitHub destination: https://github.com/maixuanlinh/Swedish3000Flashcards . Push is intentionally deferred until the owner requests it.

## Current content

The source index contains 3,000 stable Oxford-based English entries copied from the Finnish app. **All 3,000 cards now have authored Swedish text, bilingual examples and reviewed illustrations. No cards remain awaiting artwork.** Independent Swedish linguistic review remains pending.

The final checked checkpoint is `Verification/collection-complete.json`. Exact built-in generation prompts and selected images for the final 146 T cards are in `Content/Generations/t-reviewed-complete.json`; per-card generation records are in `Content/Generations/`. Each selected image was individually visually reviewed for its word, sense, memory caption, example and scene. Three T replacements correct misleading diagrams or anatomy. Reviewed reverse-order cards from `sv-2774` through `sv-3000` were preserved.

`Content/status.json` records all 3,000 cards as study-ready; `Content/artwork.json` identifies reviewed assets. `Tools/build_content.mjs` includes only authored entries whose artwork is reviewed. Generated PNG masters are preserved in `Content/Artwork/` and Android consumes the canonical JPEG derivatives. The latest iOS build uses starter media plus full-resolution WebP/MP3 packs hosted separately on Bluehost. **The complete 3,000-card collection is installed and launched on Linh Tiger iPhone** under the personal app identifier.

Stable `sv-` IDs preserve learner progress. The original headword source is the Finnish project's American Oxford-based list; UK-edition reconciliation remains pending. Nothing has been pushed to the Swedish remote.

## Build

Run `node Tools/build_content.mjs` after content updates. On macOS this uses the built-in `sips` encoder to create full-resolution JPEG quality-90 bundle copies, preserving the original generated PNG masters. The last complete A–G bundle contained 1,208 images at about 577 MiB, down from roughly 2.2 GiB of PNG copies. The growing bundle retains the same encoding policy. The manifest records master and derivative hashes, and unchanged derivatives are reused. This avoids Android package-reader overflow above 2 GiB. Android builds use an 8 GiB heap and two workers. Both native apps load the generated files in `Resources/`. Stable `sv-` IDs preserve progress across catalog updates.

iOS: open `SwedishCards.xcodeproj` and use the `3000 Swedish Words` scheme. `3000 Swedish Words Local Purchases` uses a local StoreKit fixture only. `3000 Swedish Words Personal` enables private development access. Regenerate the project with `xcodegen generate` after changing `project.yml`. Requires Xcode and iOS 17+. Select your own signing team for physical devices.

Android: open `Android/` in Android Studio. Set `ANDROID_HOME` or untracked `Android/local.properties`, use JDK 17+, and run `./gradlew :app:assembleDebug :app:testDebugUnitTest`. The adjacent `Resources/` directory is required.

The independent app identifiers are `com.linapps.swedish3000` and `com.linapps.swedish3000.personal` (iOS personal build). They cannot overwrite the Finnish apps or their progress. Speech uses `sv-SE` for Swedish and `en-GB` for English. The iOS interface and S app icon now use Swedish-flag-inspired blue, with small yellow accents. Card artwork colours are unchanged by theming. Store publication still requires the live purchase product, published Swedish privacy/support pages, final branding approval, and distribution setup.

## Reference

The Finnish iOS app remains the design reference. `References/` holds inherited documentation and tests; historical Finnish release evidence is not proof of Swedish verification. The original baseline remains available in the separate Finnish repository.

## Verification

The complete 3,000-card build passed 10 iOS unit tests, one iOS interface test and all 26 Android unit tests. Both builds and the signed iPhone build succeeded. All 3,005 packaged content files per platform match the shared resources by SHA-256; original and derivative image hashes also pass. The collection was installed and launched successfully on Linh Tiger iPhone. Android tests initially exhausted local storage, then passed after clearing rebuildable files. See `Verification/collection-complete.json`.

The content builder preserves unrelated text authored during image encoding. The artwork importer merges unrelated concurrent imports. `Content/build-input.json` records exactly which reviewed IDs were captured for a build; later reverse-worker imports enter the next build.

The local native baseline builds on both platforms. The iPhone 16 Pro simulator passed 11 tests including study/navigation and content/progress checks. Android passed 26 unit tests, built both the debug app and interface-test APK, and passed lint with 0 errors and 13 warnings. Android device testing is pending because no device or emulator was available. The Android APK's content hashes match iOS `Resources/` files. See `Verification/native-baseline.json` and `Verification/iPhone-study.png` for the exact recorded scope. No Swedish repository push has been performed.

## Quality audit and iOS theme — 2026-11-01

All 3,000 production review records and original image hashes were audited, and fresh OCR read every bundled image. The 69 OCR warnings were individually inspected and were recognition errors. The production flags do not prove independent reviewer coverage. Five wording/sense improvements and one calendar-scene correction have reviewed replacement images; original PNG masters and provenance remain archived. See `Verification/QualityAudit/review-summary.json` and its supporting evidence.

This audit does **not** certify the collection error-free. Independent Swedish proofreading and a final scene/sense sign-off remain open. The iOS blue theme changes interface colours and app icons only; it does not recolour the 3,000 illustrations. Local purchase tests cover the one-time full collection unlock and restore. Real App Store configuration and TestFlight validation remain release work.

The blue iOS personal build was installed and launched on Linh Tiger iPhone; all 3,005 packaged content files match the updated resources. Shared content verification passes. The expanded iOS checks currently pass 21 unit test methods and fail the successful-purchase/restore method (2 assertions); interface checks pass study/navigation and free autoplay, fail two StoreKit scenarios, and skip the Personal-only test under Debug. These are open release blockers, not a purchase sign-off. Evidence: `build/quality-blue-final-tests.xcresult`. Android must be rebuilt to include the six QA revisions.

## Lightweight iOS recorded-audio test build — 2026-11-01

Build **0.1 (2)** is installed on Linh Tiger iPhone under the existing personal app identity. The app wordmark now matches the official Finnish layout: **3000 / SWEDISH / WORDS**, in ivory on blue. The signed app is 40,714,118 bytes and bundles only 21,716,927 bytes of starter media, all 3,000 vocabulary entries/examples and the manifests. It does not bundle all original images or speech models. The phone was locked when automatic launch was attempted; open Swedish Words Dev to test.

The new `https://essaykingapp.com/swedish3000/v1/` directory contains 120 immutable packs with 3,000 full-dimension WebP images and 8,675 distinct prerecorded MP3 clips for 9,000 playback positions. Total media is 656,615,975 bytes. Matching English audio reuses the Finnish recordings; Swedish uses the publisher’s NST Swedish model. Originals, spelling, meanings and learner IDs are retained. The first 100 lessons’ media works without network or installed device voices; remaining media loads as needed, with optional full offline download. The Finnish media directory is unchanged. See `MediaDelivery/README.md` and `NOTICE.md`.

All 8,675 recordings passed exact mapping, checksum, MP3 decoding and non-silent-signal checks. All local image dimensions, assets and pack hashes pass. Live HTTPS checks pass all 120 pack sizes, image/Swedish/English byte ranges and a full pack hash. The iOS checks pass 28 core/media tests (one Personal-only test skipped under Debug) plus the hosted image/audio/cache/offline-pack integration test. Earlier StoreKit verification failures remain separate release work and were excluded from this audio-focused run. Human pronunciation and independent Swedish proofreading sign-off remain pending. Evidence: `Verification/RecordedAudio/test-build-summary.json`.

After future lesson changes, run the content builder, regenerate and verify the media, upload new immutable packs before publishing their manifest, and regenerate the Xcode project. Preserve older hosted packs for installed app versions. No App Store release, TestFlight distribution, Android media migration or Git push was performed in this step.

### App Store preparation — 2 November 2026

Created the independent Swedish App Store record **6829552895** (`com.linapps.swedish3000`, SKU `swedish3000-ios`) and non-consumable **6829553764** (`com.linapps.swedish3000.complete`). The app download is free, iPhone/iPad only, with manual release selected. Five real app screenshots for each required iPhone/iPad display are uploaded. English metadata, Education category and age questionnaire are saved. The global calculated rating is 13+ (regional variations apply). IAP localization, availability, review notes and review screenshot are saved; its price still awaits user confirmation.

Published Swedish landing/support/privacy pages at `https://essaykingapp.com/swedish3000/` and connected the support/privacy links in the app and listing. Privacy-label answers are saved as a conservative draft for technical hosting logs; the publication confirmation was not accepted. Confirm hosting retention, source-content rights and the account's inherited non-trader status before submission.

Release **1.0 (4)** archives successfully and its signed app occupies **35,230,389 bytes**, including **21,716,927 bytes** of starter media. Optional remaining media is **634,899,048 bytes**. These are package/storage measurements, not Apple's processed App Store download estimate. Export/upload is blocked because Xcode does not have an account for signing team `2FN25VD7TR`; the project is open in Xcode's Signing & Capabilities screen for reconnection. Personal build identity/version/progress remains separate.

Purchase entitlement checks now reconcile delayed StoreKit cache updates and overlapping status checks. Twelve purchase unit tests pass. All three customer purchase UI tests pass on a fresh iOS 18.3.1 simulator, including buy, relaunch and refund relocking. The old iOS 26.5 StoreKit UI controller reported a development-installation error; real sandbox/TestFlight validation remains required. General customer screenshot flows pass on iOS 18.3.1 iPhone/iPad and iOS 26.5 iPhone. Distinct starter artwork survives iOS display decoding. Search dismisses its keyboard when opening a lesson or submitting a query.

See `Verification/ReleasePreparation/store-setup.json` for exact evidence, current store URLs and outstanding release checks. Nothing has been submitted to review or released. Do not describe local StoreKit tests as live customer purchase verification.


Release preparation follow-up: the user reconnected the Linapps Apple Account in Xcode, authorized the same Finnish €11.99 base price and authorized reuse of the App Review contact. The real Swedish IAP now has saved pricing (Finland €11.99, Sweden 129 SEK, United States US$9.99), and the review contact is saved. Build **1.0 (4)** exported successfully (27,079,358-byte upload package) and uploaded. Final build **1.0 (5)** additionally aligns the bundled privacy manifest with the prepared technical-diagnostics disclosure; archive and App Store upload both succeeded. Apple processing, privacy publication approval, live purchase verification and the other release checks in `store-setup.json` remain pending. Earlier signing-block notes above are historical and resolved.

## Android current Finnish parity port — 2 November 2026

The Swedish native Android app now follows the current Finnish Android source, including prerecorded audio, lazy hosted media, speculative prefetch, WorkManager offline downloads, current study options, billing reconciliation and reminder artwork. The app retains `com.linapps.swedish3000`, the Swedish progress database and stable `sv-` IDs. Its UI uses the iOS blue palette and official Swedish iOS icon. All 3,000 entries, translations, examples and media come from Swedish iOS. One existing iOS English clarification (`match (contest)`) is retained; source IDs match Finnish.

Both platforms use the existing Swedish Bluehost directory and exact same manifest: 120 immutable packs, 3,000 illustrations and 8,675 distinct recordings for 9,000 audio positions. Normal Android builds include 21,716,927 bytes of starter media and download remaining media as needed or optionally for offline study. No new hosting upload is needed for unchanged shared media. Swedish signing environment variables are separate from Finnish.

Debug app and instrumentation APK build; 44 unit tests pass; lint has no errors and 27 warnings. Shared-source/master provenance, APK metadata and starter-pack hashes, every media lookup and live hosting checks pass. The app installs on Samsung A54 alongside Finnish. Three physical-device smoke tests pass: Swedish study/search/progress, offline controls, and hosted image/audio playback in both languages. Four phone screenshots are saved under `Verification/Android/screenshots/`. Google Play application/product/license setup, Swedish signing and actual purchase testing remain release work. Nothing was pushed or published to Google Play. See `Verification/Android/port-summary.json` and `Android/README.md`.

Android follow-up: search focus and the keyboard now clear when switching tabs or opening word details. The final APK rebuilt with passing lint, matches the shared metadata/starter packs exactly, and passed all three physical-device smoke tests again. Final screenshots include the unobstructed Progress and offline-download screens.

## Android Google Play preparation — 2 November 2026

Created the independent Play app **4976374116707766861**, `com.linapps.swedish3000`, after owner approval of the two creation declarations. The en-US listing, blue icon, feature graphic and four phone screenshots are saved. Education, support contact and five factual app-content declarations are saved. One-time Premium product `swedish_complete`, buy option `swedish-lifetime`, is Active; owner-approved Finland price €11.99, Google-generated Sweden 129 SEK / US $10.99. Signing uses a new Swedish-only key outside the repository with its password in Keychain.

Signed **1.0 (1)** uploaded and processed as an internal draft. The concurrent iOS hosting migration requires replacement with signed **1.0 (2)**, now built and validated against `https://yki.essaykingapp.com/swedish3000/v1`. New-host checks pass all 120 pack headers, three image/audio ranges and a full pack hash. Metadata and starter packs match iOS. The Samsung disconnected before the updated YKI debug APK could be installed; previous physical checks do not verify this new endpoint or actual Play purchases.

After explicit owner approval, build **1.0 (2)** was uploaded and published to the internal track. Console confirms **Active — Available to internal testers**, restricted to the existing one-account owner tester list. Build 1 remains only in the artifact library. The internal invitation is verified at https://play.google.com/apps/internaltest/4701647930868433693. Play currently uses the temporary name `com.linapps.swedish3000 (unreviewed)` until app setup/review are complete. Google reports a 25.9 MB new-install size. No public Android production release occurred. Android privacy/support publication, remaining content declarations and actual Play purchase/restore/refund tests remain release work. Evidence: `Verification/Android/play-internal-active-build2.png`, `play-internal-invite-build2.png` and `play-console-state.json`.

## YKI domain migration and Apple submission — 2 November 2026

Swedish pages and all 120 immutable media packs now live under `https://yki.essaykingapp.com/swedish3000/`. Support/privacy links, app media URLs and store metadata use the YKI subdomain. The old Swedish directory redirects to the new location for installed test builds. The shared YKI homepage adds Swedish support/privacy footer links; Finnish support/privacy pages remain unchanged. All pack lengths, representative media ranges, a complete pack hash, page hashes, redirects and native iOS image/audio/cache/offline integration pass. See the two `yki-*-verification` / migration reports in `Verification/ReleasePreparation/`.

Build **1.0 (6)** archived and uploaded successfully. The published App Privacy label matches the bundled manifest. Under explicit user authorization, iOS **1.0 (6)** and **3000 Swedish Words Complete** were submitted together; both visibly show **Waiting for Review**. Submission ID: `d5ea4cfc-76eb-42cd-bdd3-83c8606b3969`. Pricing remains Finland €11.99 / Sweden 129 SEK; app download is free. Manual release remains selected. Apple approval, independent Swedish/audio sign-off and live sandbox purchase/restore validation remain pending before public release. Evidence and current URLs: `Verification/ReleasePreparation/store-setup.json` and `apple-submitted-build6.png`. Earlier preparation/blocker entries above are historical.

## Apple Guideline 2.1 response and physical video — 2 November 2026

Apple requested additional new-app information and a physical-device video; its message did not identify a specific app crash. A 55-second walkthrough was recorded on Linh Tiger iPhone (iPhone 16 Plus, iOS 26.6.1), using a development-signed copy of the unchanged 1.0 (6) application source. The final physical UI test passed (1 test, 0 failures), including launch, study, search, free lesson/audio controls, an unlocked paid book lesson with hosted artwork and offline controls. The owner confirmed Apple’s sandbox purchase hardware prompt; no charge was made, and the entitlement persisted to the subsequent recorded launch. The earlier local StoreKit controller failed to disable dialogs; that incomplete recording was not submitted. The final video has no account email visible in sampled frames.

Uploaded `Verification/ReleasePreparation/Swedish3000-iPhone-review.mp4` and saved the six-part response in App Review Notes (verified after reload). Both iOS 1.0 (6) and the Complete IAP were resubmitted together under submission `d5ea4cfc-76eb-42cd-bdd3-83c8606b3969`; both visibly show **Waiting for Review**. Manual public release is retained. Evidence: `Verification/ReleasePreparation/apple-resubmitted-with-video.png`, `physical-review-video.json`, `review-notes-resubmission.txt`, and `build/physical-review-final.xcresult`. Restore validation and independent Swedish/audio sign-off remain pending before public release; this recording does not certify every lesson error-free.
