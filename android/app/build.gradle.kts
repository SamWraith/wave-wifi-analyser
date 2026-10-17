import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyFile = rootProject.file(providers.gradleProperty("waveSigningPropertiesFile").orElse("key.properties").get())
val releaseKey = Properties().apply {
    if (providers.gradleProperty("waveSigningMode").orElse("production").get() == "production" && releaseKeyFile.exists()) {
        releaseKeyFile.inputStream().use { load(it) }
    }
}

// Production is the default. Explicit alternatives never read private signing data.
val waveSigningMode = providers.gradleProperty("waveSigningMode").orElse("production").get()
require(waveSigningMode in setOf("production", "development", "unsigned")) {
    "waveSigningMode must be production, development or unsigned"
}
val validateWaveReleaseSigning = tasks.register("validateWaveReleaseSigning") {
    doLast {
        if (waveSigningMode == "production") {
            require(releaseKeyFile.isFile && listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
                .all { !releaseKey.getProperty(it).isNullOrBlank() }) {
                "Production signing requires complete android/key.properties. Use -PwaveSigningMode=development for local builds or -PwaveSigningMode=unsigned for F-Droid."
            }
            require(file(releaseKey.getProperty("storeFile")).isFile) { "Release keystore is missing." }
        }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateWaveReleaseSigning)
}

android {
    namespace = "com.samirpandey.wifi_analyser"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.samirpandey.wifi_analyser"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (waveSigningMode == "production" && releaseKeyFile.isFile &&
            listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
                .all { !releaseKey.getProperty(it).isNullOrBlank() }) {
            create("release") {
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when (waveSigningMode) {
                "development" -> signingConfigs.getByName("debug")
                "unsigned" -> null
                else -> signingConfigs.findByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
