# 3000 Swedish Words for Android

Native Kotlin/Jetpack Compose app copied from Finnish baseline `fa9932c`, retaining its design and interaction structure. Application ID: `com.linapps.swedish3000`. This installs separately from Finnish and uses its own storage and Swedish (`sv-SE`) speech. Version `0.1.0-dev`, code 1.

The current development build includes 211 authored A-set word pairs and examples, with one finished card image. Other images and all B–Z content remain in progress. See `../Content/status.json` for completion counts. Finnish illustrations are never used as substitutes. Independent Swedish linguistic review is pending.

Open this folder in Android Studio. Use its bundled JDK (17+) and Android SDK 36, then select `app` and a device or emulator. Minimum API: 26. Keep the adjacent `Resources/` directory in place.

```sh
# From the repository root after content edits:
node Tools/build_content.mjs

# From Android/:
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
python3 tools/verify_content.py
```

Set `ANDROID_HOME` or create an untracked `local.properties` containing `sdk.dir=/your/Android/sdk`. Set `JAVA_HOME` to a compatible JDK if necessary. The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. Install an offline Swedish TTS voice for pronunciation.

SwiftUI iOS and Compose Android consume the same resource files. Stable `sv-` IDs keep progress intact as more cards are added. App labels, prompts, reminder text, and speech are Swedish-specific; the UI keeps the original layout.

Google Play purchases, signing, final icons, and Swedish privacy/support publication are not configured. The `-PplayDistribution=true` configuration is inherited for future setup; it must use this app's own store and signing identities. Historical Finnish release documents and signing helpers are archived under `../References/` and must not be used to sign Swedish releases.
