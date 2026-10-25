plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val playDistribution = providers.gradleProperty("playDistribution").orNull == "true"
val uploadStoreFile = providers.environmentVariable("YKI_UPLOAD_STORE_FILE").orNull
val uploadKeyAlias = providers.environmentVariable("YKI_UPLOAD_KEY_ALIAS").orNull
val uploadStorePassword = providers.environmentVariable("YKI_UPLOAD_STORE_PASSWORD").orNull
val uploadKeyPassword = providers.environmentVariable("YKI_UPLOAD_KEY_PASSWORD").orNull
val signingValues = listOf(uploadStoreFile, uploadKeyAlias, uploadStorePassword, uploadKeyPassword)
require(signingValues.all { it == null } || signingValues.all { !it.isNullOrBlank() }) {
    "Provide all four YKI_UPLOAD_* signing environment variables, or none for an unsigned preparation bundle."
}

val prepareContent by tasks.registering(Sync::class) {
    from(rootProject.file("../Resources")) {
        include("catalog3000.json", "starter100.json", "examples3000.json", "artworkBriefs.json", "BundledArtwork/manifest.json")
        if (!playDistribution) include("BundledArtwork/**")
    }
    into(layout.buildDirectory.dir(if (playDistribution) "generated/playMetadataAssets" else "generated/sisuAssets"))
}
android {
    namespace = "com.linapps.swedish3000"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.linapps.swedish3000"
        minSdk = 26
        targetSdk = 36
        versionCode = if (playDistribution) providers.gradleProperty("releaseVersionCode").orElse("1").get().toInt() else 1
        versionName = if (playDistribution) providers.gradleProperty("releaseVersionName").orElse("0.1").get() else "0.1.0-dev"
        buildConfigField("String", "PLAY_PRODUCT_ID", "\"${providers.gradleProperty("playProductId").getOrElse("")}\"")
        buildConfigField("String", "PLAY_LICENSE_KEY", "\"${providers.gradleProperty("playLicenseKey").getOrElse("")}\"")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    if (playDistribution) assetPacks += ":illustrations"
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
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
    testImplementation("androidx.test:core:1.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:1.10.0")
    debugImplementation("androidx.compose.ui:ui-test-manifest:1.10.0")
}
