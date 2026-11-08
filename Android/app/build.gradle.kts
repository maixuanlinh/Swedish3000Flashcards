plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val playDistribution = providers.gradleProperty("playDistribution").orNull == "true"
val phonePreview = providers.gradleProperty("phonePreview").orNull == "true"
require(!phonePreview || !playDistribution) { "Phone previews must not use the production Play package." }
val mediaBaseUrl = providers.gradleProperty("mediaBaseUrl").orElse("https://yki.essaykingapp.com/swedish3000/v1").get()
val playProductId = providers.gradleProperty("playProductId").getOrElse("")
val playLicenseKey = providers.gradleProperty("playLicenseKey").getOrElse("")
require(mediaBaseUrl.isEmpty() || mediaBaseUrl.matches(Regex("https://[a-zA-Z0-9.-]+(/[a-zA-Z0-9_./-]*)?"))) { "Provide an HTTPS lesson-media directory URL." }
require(!playDistribution || mediaBaseUrl.isNotBlank()) { "Play builds need -PmediaBaseUrl pointing to the verified hosted lesson directory." }
require(!playDistribution || (playProductId.isNotBlank() && playLicenseKey.isNotBlank())) { "Play builds need the active product ID and Play license key." }
val uploadStoreFile = providers.environmentVariable("SWEDISH_UPLOAD_STORE_FILE").orNull
val uploadKeyAlias = providers.environmentVariable("SWEDISH_UPLOAD_KEY_ALIAS").orNull
val uploadStorePassword = providers.environmentVariable("SWEDISH_UPLOAD_STORE_PASSWORD").orNull
val uploadKeyPassword = providers.environmentVariable("SWEDISH_UPLOAD_KEY_PASSWORD").orNull
val signingValues = listOf(uploadStoreFile, uploadKeyAlias, uploadStorePassword, uploadKeyPassword)
require(signingValues.all { it == null } || signingValues.all { !it.isNullOrBlank() }) {
    "Provide all four SWEDISH_UPLOAD_* signing environment variables, or none for an unsigned preparation bundle."
}

val prepareContent by tasks.registering(Sync::class) {
    from(rootProject.file("../Resources")) {
        include("catalog3000.json", "starter100.json", "examples3000.json", "artworkBriefs.json", "BundledArtwork/manifest.json")
    }
    from(rootProject.file("../MediaDelivery/generated/assets")) { include("lesson-media.json","pack-*.bin") }
    // A build with no server URL is a complete offline development installation.
    if (mediaBaseUrl.isEmpty()) from(rootProject.file("../MediaDelivery/public/v1")) { include("pack-*.bin") }
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    into(layout.buildDirectory.dir("generated/lessonAssets"))
    doFirst { require(rootProject.file("../MediaDelivery/generated/assets/lesson-media.json").isFile) { "Generate lesson media with Tools/media/build_lesson_media.py before building." } }
}
android {
    namespace = "com.linapps.swedish3000"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.linapps.swedish3000"
        if (phonePreview) applicationIdSuffix = ".preview"
        manifestPlaceholders["appLabel"] = if (phonePreview) "3000 Swedish Words Preview" else "3000 Swedish Words"
        minSdk = 26
        targetSdk = 36
        versionCode = if (playDistribution) providers.gradleProperty("releaseVersionCode").orElse("3").get().toInt() else 3
        versionName = if (phonePreview) "1.1.0-preview" else if (playDistribution) providers.gradleProperty("releaseVersionName").orElse("1.1.0").get() else "1.1.0-dev"
        buildConfigField("String", "PLAY_PRODUCT_ID", "\"$playProductId\"")
        buildConfigField("String", "PLAY_LICENSE_KEY", "\"$playLicenseKey\"")
        buildConfigField("String", "MEDIA_BASE_URL", "\"$mediaBaseUrl\"")
        testInstrumentationRunner = "com.linapps.swedish3000.ParityTestRunner"
    }
    sourceSets["main"].assets.srcDir(prepareContent.map { it.destinationDir })
    signingConfigs {
        if (uploadStoreFile != null) create("upload") {
            storeFile = file(uploadStoreFile)
            storePassword = uploadStorePassword
            keyAlias = uploadKeyAlias
            keyPassword = uploadKeyPassword
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (uploadStoreFile != null) signingConfig = signingConfigs.getByName("upload")
        }
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    testOptions { unitTests.isIncludeAndroidResources = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    androidResources { noCompress += "bin" }
}
tasks.named("preBuild").configure { dependsOn(prepareContent) }
dependencies {
    implementation("com.android.billingclient:billing:8.3.0")
    implementation("androidx.activity:activity-compose:1.12.1")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.compose.ui:ui:1.10.0")
    implementation("androidx.compose.foundation:foundation:1.10.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.10.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.work:work-runtime:2.10.4")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
    testImplementation("androidx.test:core:1.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:1.10.0")
    debugImplementation("androidx.compose.ui:ui-test-manifest:1.10.0")
}
