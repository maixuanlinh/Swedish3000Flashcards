# Swedish lesson media

The iOS app follows the Finnish app's hosted-pack delivery design. It includes all 3,000 vocabulary entries, examples, learning features, a media manifest and the first 100 starter lessons' media. Remaining images and prerecorded audio load from a separate `https://yki.essaykingapp.com/swedish3000/v1/` directory. The Finnish hosting folder is not modified.

All pronunciation playback uses MP3 recordings through AVAudioPlayer. It does not require a Swedish system voice. Swedish uses Piper's `sv_SE-nst-medium` model. Matching English clips reuse the Finnish release's `en_US-ljspeech-high` recordings after checking both the model hash and the recording hash. Swedish spelling alternatives separated by a slash are spoken with a short comma pause; terminal compound-prefix hyphens are not spoken. Exact display text remains the recording lookup key.

Media packs use the Finnish `sisu-lesson-media-v1` format: immutable SHA-256 filenames, packs of at most 8 MB, byte ranges for individual images/audio, and complete-pack verification for optional offline downloads. Images retain their full dimensions and card design; WebP quality-85 copies reduce transfer size. All original artwork and source resources are retained.

Progress and playback settings both expose **Download for offline study**. Downloading the complete collection is optional. Downloads can pause and continue at pack boundaries. Keep the app open while downloading; completed packs remain available after relaunch. Removing downloaded media preserves learning history and personal artwork. Notification scheduling never starts a media download.

## Generation and verification

Use Python 3.12+ with `Tools/media/requirements.txt`. Download the published Swedish checkpoint and matching JSON configuration into `MediaDelivery/models/`; supply the English checkpoint used for the Finnish release. Model cards and links are recorded in `NOTICE.md`. Models, tools, local caches and credentials are not phone or hosting assets.

Run `Tools/media/build_lesson_media.py`, then `Tools/media/verify_audio.py` and `Tools/media/verify_lesson_media.py`. Generation resumes from checksum-verified recordings and image copies. The audio verification checks the lesson mapping, hashes, MP3 decoding, sample format and non-silent signal of every recording. Listening review remains necessary for pronunciation.

Only `public/v1/` is uploaded to the new Swedish hosting directory. `generated/assets/` contains the manifest and starter packs for the iOS build. Upload packs before exposing the manifest, then run `Tools/media/verify_hosted_media.py` against the live HTTPS URL. A hosting archive must exclude speech models, work files, credentials and other websites' files.

Hosting and device verification results are recorded under `Verification/RecordedAudio/`. App Store release remains separate from this personal testing build.

## Verified testing release — 2026-11-01

The media is deployed and verified at the Swedish URL above. There are 120 packs containing 3,000 full-dimension card images and 8,675 distinct recordings, totaling 656,615,975 bytes. Starter packs are 21,716,927 bytes. The signed iPhone test build is 40,714,118 bytes, version 0.1 (2), and is installed under the existing personal app identity. Automatic launch was denied because the iPhone was locked; open Swedish Words Dev to test.

Checks pass every local pack/asset hash, image dimensions, all 8,675 MP3 decodes and non-silent signals, all 120 hosted pack sizes, three hosted image/audio ranges and a full hosted pack hash. iOS passes 28 core/media tests (one Personal-only test skipped under Debug), plus the live hosted/cache/offline integration test. The earlier StoreKit release blockers are not resolved by this media work.

Only the new Swedish directory was published. The five temporary upload archives were moved out of the website to the account’s private `tmp/swedish3000-upload-20261101` folder. The Finnish media and WordPress files were not edited. Evidence is in `Verification/RecordedAudio/test-build-summary.json`.
