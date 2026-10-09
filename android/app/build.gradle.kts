import com.android.build.api.artifact.SingleArtifact
import java.io.FileInputStream
import java.util.Base64
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

// Which shop this build is for - the same `--dart-define` the Dart side reads
// (lib/core/constants/distribution.dart), so one flag sets both:
//   flutter build appbundle --dart-define=FLASHLEARN_DISTRIBUTION=play
// Flutter hands Gradle its defines as `-Pdart-defines=<base64>,<base64>,...`.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        ?.mapNotNull { define ->
            val eq = define.indexOf('=')
            if (eq > 0) define.substring(0, eq) to define.substring(eq + 1) else null
        }
        ?.toMap()
        ?: emptyMap()
val isPlayBuild = dartDefines["FLASHLEARN_DISTRIBUTION"] == "play"

// The website APKs keep the original id, so every tablet that installed one
// keeps accepting updates (and its profiles). Google Play refuses any
// "com.example" id, so the Play build is published under its own - a separate
// app on a device. The iOS bundle id is the same string.
val websiteApplicationId = "com.example.pwdpwdpwd"
val storeApplicationId = "io.github.jpaestedstuprog.flashlearnpwd"

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
        applicationId = if (isPlayBuild) storeApplicationId else websiteApplicationId
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

// Google Play allows USE_EXACT_ALARM only for apps whose core purpose is an
// alarm clock or a calendar. The Play build drops it from the merged manifest
// and keeps SCHEDULE_EXACT_ALARM, which the user grants ("Alarms &
// reminders"); without that grant, RoutineAlarms.kt and the Dart schedulers
// already fall back to inexact alarms. Website APKs are unchanged.
abstract class DropPermissionsTask : DefaultTask() {
    @get:InputFile
    abstract val mergedManifest: RegularFileProperty

    @get:OutputFile
    abstract val updatedManifest: RegularFileProperty

    @get:Input
    abstract val permissions: ListProperty<String>

    @TaskAction
    fun drop() {
        var manifest = mergedManifest.get().asFile.readText()
        for (permission in permissions.get()) {
            val element = Regex(
                """\s*<uses-permission\s+android:name="${Regex.escape(permission)}"[^>]*/>""",
            )
            check(element.containsMatchIn(manifest)) {
                "$permission is not in the merged manifest - update DropPermissionsTask."
            }
            manifest = manifest.replace(element, "")
        }
        updatedManifest.get().asFile.writeText(manifest)
    }
}

androidComponents {
    onVariants { variant ->
        if (isPlayBuild) {
            val task = project.tasks.register<DropPermissionsTask>(
                "drop${variant.name.replaceFirstChar { it.uppercase() }}PlayPermissions",
            ) {
                permissions.set(listOf("android.permission.USE_EXACT_ALARM"))
            }
            variant.artifacts.use(task)
                .wiredWithFiles(
                    DropPermissionsTask::mergedManifest,
                    DropPermissionsTask::updatedManifest,
                )
                .toTransform(SingleArtifact.MERGED_MANIFEST)
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Provides Theme.Material3.* parents used by res/values*/styles.xml.
    implementation("com.google.android.material:material:1.12.0")
    // Backport for the Android 12 Splash Screen API on older versions.
    implementation("androidx.core:core-splashscreen:1.0.1")
}
