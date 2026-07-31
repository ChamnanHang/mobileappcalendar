# Flutter wraps its own engine rules; these cover the plugins this app uses.

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Play Core is referenced by Flutter's deferred-components support even when
# the app does not use deferred loading.
-dontwarn com.google.android.play.core.**
