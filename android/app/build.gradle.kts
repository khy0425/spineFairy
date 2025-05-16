plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.spin_fairy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // 플러그인 호환성을 위해 NDK 버전 업데이트

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Java 8 기능 사용을 위한 desugaring 설정
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.spin_fairy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23 // AdMob 최신 버전을 사용하려면 최소 23 이상 필요
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
}

flutter {
    source = "../.."
}

dependencies {
    // AdMob 종속성 추가
    implementation("com.google.android.gms:play-services-ads:23.0.0")
    // Java 8 기능을 위한 desugaring 라이브러리 (버전 업데이트)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
