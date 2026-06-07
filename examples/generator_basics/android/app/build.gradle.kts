plugins {
  id("com.android.application")
  id("kotlin-android")
  id("org.jetbrains.kotlin.plugin.compose") version "2.2.20"
  // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
  id("dev.flutter.flutter-gradle-plugin")
}

android {
  namespace = "es.antonborri.generator_basics"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

  defaultConfig {
    // TODO: Specify your own unique Application ID
    // (https://developer.android.com/studio/build/application-id.html).
    applicationId = "es.antonborri.generator_basics"
    // You can update the following values to match your application needs.
    // For more information, see: https://flutter.dev/to/review-gradle-config.
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }

  buildTypes {
    release {
      // TODO: Add your own signing config for the release build.
      // Signing with the debug keys for now, so `flutter run --release` works.
      signingConfig = signingConfigs.getByName("debug")
    }
  }
  buildFeatures { compose = true }
}

flutter { source = "../.." }

dependencies { implementation("androidx.glance:glance-appwidget:1.1.1") }
