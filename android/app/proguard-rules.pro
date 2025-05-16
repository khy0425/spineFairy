# Google Mobile Ads SDK 관련 규칙
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Flutter 관련 규칙
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Background Service 관련 규칙
-keep class com.dexterous.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }

# Firebase 관련 규칙
-keep class com.google.firebase.** { *; }

# Google Mobile Ads 관련 규칙
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Play Core 라이브러리 관련 규칙 (분할 설치 관련)
-keep class com.google.android.play.core.** { *; }
-keepnames class com.google.android.play.core.splitcompat.SplitCompatApplication
-keepnames class com.google.android.play.core.splitinstall.** { *; }
-keepnames class com.google.android.play.core.tasks.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# 멀티덱스 관련 규칙
-keep class androidx.multidex.** { *; }

# 경고 무시
-dontwarn java.lang.invoke.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn okio.**
-dontwarn retrofit2.Platform$Java8
-dontwarn com.google.android.play.core.**

# Kotlin 관련 규칙
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlin.jvm.internal.** { *; }

# Keep your custom models  
-keep class com.alyayak.spinfairy.models.** { *; } 