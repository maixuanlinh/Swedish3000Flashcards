plugins { id("com.android.asset-pack") }

assetPack {
    packName.set("illustrations")
    dynamicDelivery { deliveryType.set("install-time") }
}

// Generated from the canonical iOS artwork; no recompression or separate source copy.
val prepareIllustrations by tasks.registering(Sync::class) {
    from(rootProject.file("../Resources/BundledArtwork")) { include("*.jpg", "*.png") }
    into(layout.projectDirectory.dir("src/main/assets/BundledArtwork"))
}
tasks.configureEach {
    if (name.startsWith("generate") || name.startsWith("package")) dependsOn(prepareIllustrations)
}
