# ProGuard rules for ParishServe release build

# Keep rules for ML Kit Text Recognition optional language modules referenced by google_mlkit_text_recognition
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**

# Keep rules for Google Play Core / Play Feature Delivery (Deferred Components) referenced by Flutter embedding
-dontwarn com.google.android.play.core.**

# Flutter embedding
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
