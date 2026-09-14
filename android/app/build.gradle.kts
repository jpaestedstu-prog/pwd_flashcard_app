plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pwdpwdpwd"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.pwdpwdpwd"
        // minSdk 29 (Android 10): guarantees gesture navigation,
        // edge-to-edge APIs, dynamic colors hooks, and Theme.Material3.*
        // parents without legacy compat shims. targetSdk 36 (Android 16).
        minSdk = 29
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Enable R8 code shrinking, obfuscation, and resource shrinking
            // for smaller APK and faster class loading.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

// firebase_messaging (the educator's "needs help" push) bundles the Firebase
// instance-id receiver itself. ML Kit's image labeling still drags in the old
// standalone firebase-iid through com.google.mlkit:linkfirebase, and the two
// define the same class, so the build fails. linkfirebase only needs it for
// models downloaded from Firebase; Word Hunt uses the bundled on-device model
// (`ImageLabelerOptions`), so the old artifact is dropped.
configurations.all {
    exclude(group = "com.google.firebase", module = "firebase-iid")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Provides Theme.Material3.* parents used by res/values*/styles.xml.
    implementation("com.google.android.material:material:1.12.0")
    // Backport for the Android 12 Splash Screen API on older versions.
    implementation("androidx.core:core-splashscreen:1.0.1")
}
