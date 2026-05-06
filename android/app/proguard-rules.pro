# Flutter-specific ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Supabase / OkHttp / Gson (used by supabase_flutter)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class com.google.gson.** { *; }

# Keep notification-related classes (flutter_local_notifications)
-keep class com.dexterous.** { *; }

# Prevent stripping of Hive adapters
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
