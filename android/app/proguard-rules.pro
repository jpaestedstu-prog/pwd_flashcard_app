# Flutter-specific ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# OkHttp / Okio / annotations (transitively used by several plugins)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class com.google.gson.** { *; }

# flutter_local_notifications + the WorkManager classes it reflects.
-keep class com.dexterous.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.core.app.** { *; }

# Firebase (Firestore, Auth, Crashlytics, Analytics). All are reflected
# at startup by FirebaseApp.initializeApp; without these rules, a
# release build will throw ClassNotFoundException on first launch.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Hive — generated *Adapter classes are looked up by name at runtime.
-keep class **.*Adapter { *; }
-keepclassmembers class * extends hive.TypeAdapter { *; }

# video_player → ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Google Play Core (deferred components / split install). The app does not
# ship deferred components, but the Flutter engine references these classes;
# R8 fails the release build without these suppressions.
-dontwarn com.google.android.play.core.**
