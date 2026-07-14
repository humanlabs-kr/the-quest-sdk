# The Quest Offerwall SDK — consumer ProGuard/R8 rules.
# Applied automatically to any app that depends on this library.

# The JS bridge is invoked reflectively by the WebView from JavaScript.
# Keep the bridge class and every @JavascriptInterface method intact.
-keep class world.humanlabs.quest.bridge.QuestBridge { *; }
-keepclassmembers class world.humanlabs.quest.bridge.QuestBridge {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclasseswithmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# LaunchToken crosses the public API boundary; keep it stable.
-keep class world.humanlabs.quest.models.LaunchToken { *; }
