package world.humanlabs.quest.bridge

import android.util.Log
import android.webkit.JavascriptInterface
import org.json.JSONObject

/**
 * The native side of the JS bridge (see `docs/BRIDGE.md`).
 *
 * Exposed to the offerwall WebView as `TheQuestAndroid`. The injected shim
 * (`window.TheQuestNative`) calls `TheQuestAndroid.postMessage(JSON.stringify(obj))`.
 *
 * SECURITY: This interface is added **only** to the WebView loading our own origin. It
 * exposes nothing but `openUrl` / `close` / `ready` — no storage, files, or arbitrary intents.
 *
 * All callbacks are dispatched off the JS (binder) thread; the listener implementation is
 * responsible for hopping to the UI thread for any UI work.
 */
internal class QuestBridge(private val listener: Listener) {

    /** Callbacks for the three supported message types. */
    interface Listener {
        fun onOpenUrl(url: String)
        fun onClose()
        fun onReady()
    }

    /**
     * Entry point invoked by JavaScript. Runs on a WebView-owned binder thread — keep it
     * cheap and never throw across the JNI boundary.
     */
    @JavascriptInterface
    fun postMessage(json: String?) {
        if (json.isNullOrEmpty()) return
        try {
            val message = JSONObject(json)
            when (message.optString("type")) {
                "openUrl" -> {
                    val url = message.optString("url")
                    if (url.isNotEmpty()) listener.onOpenUrl(url)
                }
                "close" -> listener.onClose()
                "ready" -> listener.onReady()
                else -> Log.w(TAG, "Ignoring unknown bridge message type")
            }
        } catch (e: Exception) {
            // Malformed JSON from the page must never crash the host app.
            Log.w(TAG, "Failed to parse bridge message", e)
        }
    }

    companion object {
        private const val TAG = "TheQuest"

        /** JavaScript interface name; must match the shim's transport in BRIDGE.md §3. */
        const val NAME = "TheQuestAndroid"
    }
}
