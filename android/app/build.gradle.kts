import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The signing key. It lives OUTSIDE the project folder (zipping or sharing the
// project never shares it), in ~/.flashlearn-signing — see docs/signing.md.
// It is the key every published FlashLearn APK was signed with, so installed
// copies keep accepting updates; FLASHLEARN_SIGNING_PROPERTIES may point
// elsewhere (a restored backup on another PC).
val signingPropertiesFile = file(
    System.getenv("FLASHLEARN_SIGNING_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.flashlearn-signing/key.properties",
)
// No key, no build: an APK signed with any other key could never update the
// copies already installed — and when `flutter run` meets a signature
// mismatch it UNINSTALLS the app, wiping every profile on a study tablet.
if (!signingPropertiesFile.isFile) {
    throw GradleException(
        "FlashLearn's signing key was not found at $signingPropertiesFile. " +
            "Restore it from the backup first - see docs/signing.md.",
    )
}
val signingProperties = Properties().apply {
    FileInputStream(signingPropertiesFile).use { load(it) }
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

    signingConfigs {
        create("flashlearn") {
            storeFile = file(signingProperties.getProperty("storeFile"))
            storePassword = signingProperties.getProperty("storePassword")
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        // Every build type — debug, profile and release — carries the
        // published app's signature, so any of them installs over a tablet's
        // real copy (keeping its profiles) instead of failing the check.
        configureEach {
            signingConfig = signingConfigs.getByName("flashlearn")
        }
        release {

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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Provides Theme.Material3.* parents used by res/values*/styles.xml.
    implementation("com.google.android.material:material:1.12.0")
    // Backport for the Android 12 Splash Screen API on older versions.
    implementation("androidx.core:core-splashscreen:1.0.1")
}
