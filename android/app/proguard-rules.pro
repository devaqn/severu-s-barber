# Keep metadata commonly required by reflection/serialization.
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

# Flutter embedding and generated registrant.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Firebase / Google Play services.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# sqflite Android implementation.
-keep class com.tekartik.sqflite.** { *; }

# Flutter references Play Core deferred components APIs optionally.
# In projects without Play Core dependency, suppress missing warnings.
-dontwarn com.google.android.play.core.**
