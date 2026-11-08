# ==============================================================================
# 1. FLUTTER ENGINE & WRAPPER RULES
# ==============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }
-dontwarn io.flutter.embedding.**

# ==============================================================================
# 2. GOOGLE ML KIT VISION & TEXT RECOGNITION
# ==============================================================================
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.odml.image.** { *; }

-keepnames class com.google.mlkit.** { *; }
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# Suppress warnings for unbundled CJK / Devanagari recognizers when using Latin OCR
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ==============================================================================
# 3. GOOGLE MOBILE ADS SDK (ADMOB) & UMP CONSENT
# ==============================================================================
-keep public class com.google.android.gms.ads.** {
    public *;
}
-keep public class com.google.ads.** {
    public *;
}
-keep class com.google.android.ump.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# ==============================================================================
# 4. ISAR / HIVE / NATIVE FFI & JNI PROTECTION
# ==============================================================================
-keep class dev.isar.** { *; }
-keepclassmembers class * {
    native <methods>;
}

# ==============================================================================
# 5. UCROP (IMAGE CROPPER)
# ==============================================================================
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
