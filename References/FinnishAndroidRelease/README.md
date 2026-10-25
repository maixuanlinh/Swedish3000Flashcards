# Google Play release preparation — 25 October 2026

**Status: app entry and English listing draft created in Play Console; release 1.0 (3) signed with the owner-selected Essay King key, uploaded and processed in the internal release draft; not rolled out, submitted for production review or published.** The owner signed in and explicitly confirmed both app-creation declarations. The new app belongs to Linapps Technology (developer ID `8850863360061339505`), app ID `4973686116837165298`. Package availability was confirmed, default language is en-GB, download price is free, and Education category was saved. The owner explicitly approved the public support email and HTTPS website, and both are saved. A dedicated upload key has been created outside the project with its password in macOS Keychain; the owner subsequently selected the existing Essay King keystore. Its passwords were entered locally, verified and stored in Keychain, and the signed bundle’s certificate matches the Essay King certificate. See `UPLOAD-KEY-HANDOVER.md` and `signed-bundle-check.json`. See `play-console-state.json`.

## Prepared

- App: **3000 Swedish Words**, Android package `com.linapps.swedish3000`.
- Preparation release version **1.0 (3)**. Confirm version code availability against the actual Console app before signing/uploading. Ordinary development builds keep version `1.0.0-dev29 (2)` and their existing offline APK setup.
- Optimized release AAB: `../app/build/outputs/bundle/release/app-release.aab`. **The bundle is now signed using Essay King alias `myessaykingkey`; signature verified.**
- Google Play distribution mode: `-PplayDistribution=true`. Base includes app code, vocabulary, examples and artwork metadata; a separate **install-time** `illustrations` asset pack includes the 6,000 original full images/thumbnails. No recompression or omission of canonical pictures. This keeps the base below Google's current 500 MB limit and the artwork pack below its 1.5 GB limit.
- All canonical metadata and 6,000 JPEG hashes match their source files. No illustration JPEGs are duplicated in the base. See `bundle-content-check.json`.
- Google's official bundletool 1.18.1 validates the AAB. See `bundletool-validation.log`, `base-manifest.xml` and `illustrations-manifest.xml`.
- English listing draft in `store-listing/en-GB/`: title, short/full description and internal release notes. Character limits pass (`listing-validation.json`). The public description assumes Premium has been configured and tested before production.
- Android-inclusive privacy text is drafted in `privacy-policy-android-draft.html`. The existing public policy currently describes iOS; this draft has **not** been published. Review and publish the Android update before entering that URL for an Android production release.

## Console work once signed in

1. Inspect the developer account and any existing app with this package. Reuse an existing entry/key if present. For a new entry, use the established name and Education category, English language, App (not Game), and free download with an optional one-time Complete purchase.
2. Review account verification and production eligibility. For personal developer accounts created after 13 November 2023, Google currently requires a closed test with at least 12 opted-in testers continuously for 14 days before production access can be requested. An internal test does not satisfy that closed-test requirement.
3. Check or enroll in Play App Signing. Select the correct upload keystore, alias and credentials. Keep private keys and passwords outside this project/source control and back them up securely. Do not use the Android debug key for a Play release. The owner must handle legal agreement acceptance when presented.
4. Configure the actual Google Play one-time Complete product and app licensing public key. Match the established commercial model (free app, optional one-time unlock); confirm the Android product identifier and price in this account before wiring them into the release. Apple purchases do not transfer.
5. Complete the store listing and graphical assets. Google requires a 512×512 icon and a 1024×500 feature graphic. Existing tall 1080×2340 test captures are **not ready for direct store upload**: screenshots must have a long dimension no more than twice the short dimension. Capture fresh current-UI images in a compliant emulator/device configuration, preferably 1080×1920; do not distort them. Recommended minimum is four genuine phone screenshots.
6. Review app-content declarations: ads, app access, target audience/content rating, Data safety, privacy, financial features and any Console-specific requirements. No app account/login, no ads, no microphone/camera or broad photo/storage permission is implemented. Notifications are optional, and photos/files use system pickers. Review the billing SDK's data practices before certifying Data safety; do not copy the iOS privacy label into Android automatically.
7. Upload the signed bundle to **Internal testing**, add the intended testers and license-test accounts, and obtain the Play opt-in/install link. Check the actual installed bundle offline, all artwork, Swedish/English voices, notifications, personal artwork, purchases/restore, pending/cancel/refund, and the pre-launch report.
8. Complete required closed testing if applicable, resolve the report, then prepare the public release for owner review and required declarations.

## Build the Play bundle

From `Android`:

```sh
./gradlew -PplayDistribution=true :app:bundleRelease
```

This creates an unsigned preparation bundle unless **all four** signing environment variables are available: `YKI_UPLOAD_STORE_FILE`, `YKI_UPLOAD_KEY_ALIAS`, `YKI_UPLOAD_STORE_PASSWORD`, `YKI_UPLOAD_KEY_PASSWORD`. Do not print passwords or put them in command-line flags, tracked Gradle files or chat messages. Use an existing secure key configuration or Android Studio's signing workflow.

Use `-PreleaseVersionCode=<next-unused-code>` and `-PreleaseVersionName=<version>` to deliberately select a release identity. Configure the verified public Play values using Gradle properties `playProductId` and `playLicenseKey`. They are not the upload keystore or its private password.

Normal `./gradlew :app:assembleDebug` continues to include all images in the debug APK. Do not build/store-release from a plain APK or use the iOS archive.

## Sources checked

- [Play app-size limits](https://support.google.com/googleplay/android-developer/answer/9859372?hl=en)
- [Install-time asset delivery](https://developer.android.com/guide/playcore/asset-delivery/integrate-java)
- [App signing and upload keys](https://developer.android.com/studio/publish/app-signing)
- [New personal-account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB)
- [Internal/closed testing](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)
- [Store graphics and screenshot specifications](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Data safety definitions](https://developer.android.com/about/versions/14/features/app-metadata)

## Latest Console result

Google processed signed bundle **3 (1.0)**, API 26+, target SDK 36. The English listing is **Ready to send for review**, with icon, feature graphic and four 1080×1920 phone screenshots. The owner specifically selected AI labelling for the **feature graphic only**, and that declaration was saved. Public production release, purchases, privacy, Data safety and remaining content tasks are still pending.

## Internal release result

Version **1.0 (3)** was published to the private internal track on 25 October 2026. Console showed **Active** and **Available to internal testers**, with one owner tester selected. The public production release has not been submitted. Internal testing is optional and is not the closed test required for newer personal accounts. The owner asked to focus on the public release; next inspect this account’s actual production eligibility and complete the remaining setup. Browser continuation is currently blocked because local browser use is disabled in Work settings.

## Public release preparation continued

The Production page is accessible and **Create new release** is enabled; no closed-testing gate was displayed. Ads (none), government affiliation (none), financial features (none) and health features (none) declarations are saved. Together with category/contact details and the listing, this completes six of the eleven initial setup tasks. IARC Terms of Use acceptance awaits owner approval. The Android-inclusive privacy source is prepared locally and in the GitHub editor; public publication awaits owner approval. Data safety, target audience, app access and Premium configuration still require completion. Browser access has been restored through a fresh Play Console tab.
