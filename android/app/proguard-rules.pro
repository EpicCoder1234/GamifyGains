# Flutter specific rules (essential for Flutter apps)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase related rules (critical for Firebase Core, Auth, Firestore)
# Firebase uses reflection, so these rules are vital to prevent R8 from removing needed classes.
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.** { *; } # Important for Google Play Services used by Firebase

# Specific rules for flutter_background_service and its dependencies
# Keep the background service class itself
-keep class com.dexterous.flutter_background_service.** { *; }
# Keep the BroadcastReceiver for background service to restart/handle commands
-keep class com.dexterous.flutter_background_service.BackgroundServiceReceiver { *; }
# Keep shared_preferences classes (used by WorkoutService for state persistence)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
# Keep permission_handler classes
-keep class com.baseflow.permissionhandler.** { *; }
# Keep device_info_plus classes
-keep class dev.fluttercommunity.plus.device_info.** { *; }
# Keep sqflite classes
-keep class com.tekartik.sqflite.** { *; }
-keep class com.tekartik.sqflite.operation.** { *; }
# Keep flutter_local_notifications classes (if you added this for explicit channel creation)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }

# If you have custom models or data classes that are being serialized/deserialized (e.g., in JSON),
# you might need rules like this (adjust package name):
# -keep class your.app.package.name.models.** { *; }

# Optional: For any WebView/HTML related content, sometimes these are needed
# -keep class android.webkit.** { *; }

# For general issues, this can sometimes help but is very broad:
# -dontwarn com.google.common.base.Optional
