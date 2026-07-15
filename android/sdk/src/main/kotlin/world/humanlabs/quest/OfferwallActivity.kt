package world.humanlabs.quest

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.RenderProcessGoneDetail
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import world.humanlabs.quest.bridge.QuestBridge
import world.humanlabs.quest.internal.LaunchUrlBuilder
import world.humanlabs.quest.models.LaunchToken

/**
 * Full-screen Activity that hosts the offerwall WebView with a lightweight native header.
 *
 * Deliberately built for low-end devices: XML layout (no Compose), a single reused WebView,
 * conservative WebView settings, and graceful handling of render-process death / OOM.
 */
class OfferwallActivity : AppCompatActivity(), QuestBridge.Listener {

    private var webView: WebView? = null
    private lateinit var progressBar: ProgressBar
    private lateinit var errorView: View

    private var requestId: String? = null
    private var appId: String = ""
    private var baseUrl: String = ""
    private var userId: String = ""
    private var entry: TheQuestSession.Entry? = null

    private var closeInvoked = false

    // ── File chooser (<input type="file">) ──────────────────────────────────────
    // Pending WebView callback awaiting the picked file uris. Delivered exactly once.
    private var filePathCallback: ValueCallback<Array<Uri>>? = null

    // Registered at construction (before STARTED), as ActivityResult contracts require.
    // The system photo picker is permission-free by design (out-of-process); on devices
    // without it, PickVisualMedia transparently falls back to ACTION_GET_CONTENT (also
    // permission-free). No READ_MEDIA_IMAGES / CAMERA permission is ever needed.
    private val pickSingleImage =
        registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
            deliverFileChooserResult(if (uri != null) arrayOf(uri) else emptyArray())
        }

    private val pickMultipleImages =
        registerForActivityResult(ActivityResultContracts.PickMultipleVisualMedia()) { uris ->
            deliverFileChooserResult(uris.toTypedArray())
        }

    // Fallback for non-image `accept` values: SAF document picker (permission-free).
    private val pickDocument =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            deliverFileChooserResult(
                WebChromeClient.FileChooserParams.parseResult(result.resultCode, result.data)
                    ?: emptyArray(),
            )
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        requestId = intent.getStringExtra(EXTRA_REQUEST_ID)
        appId = intent.getStringExtra(EXTRA_APP_ID).orEmpty()
        baseUrl = intent.getStringExtra(EXTRA_BASE_URL).orEmpty()
        userId = intent.getStringExtra(EXTRA_USER_ID).orEmpty()
        entry = TheQuestSession.get(requestId)

        if (appId.isEmpty() || baseUrl.isEmpty() || userId.isEmpty()) {
            Log.e(TAG, "OfferwallActivity started without required extras; finishing.")
            finish()
            return
        }

        setContentView(R.layout.tq_offerwall_activity)
        applyWindowInsets()

        progressBar = findViewById(R.id.tq_progress)
        errorView = findViewById(R.id.tq_error)

        findViewById<Button>(R.id.tq_retry).setOnClickListener { startLoad() }
        // No native header — the web renders its own close button (bridge → onClose). This
        // error-screen close is the fallback when the web fails to load.
        findViewById<Button>(R.id.tq_error_close).setOnClickListener { dismiss() }

        setupWebView()
        registerBackHandler()

        startLoad()
    }

    /** Pad the root for status/navigation bars so content is never drawn under system bars. */
    private fun applyWindowInsets() {
        val root = findViewById<View>(R.id.tq_root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.updatePadding(top = bars.top, bottom = bars.bottom, left = bars.left, right = bars.right)
            insets
        }
    }

    private fun setupWebView() {
        val webView = WebView(this)
        this.webView = webView

        // Insert the WebView into the weighted container, below the header.
        val container = findViewById<ViewGroup>(R.id.tq_webview_container)
        container.addView(
            webView,
            0,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            @Suppress("DEPRECATION")
            databaseEnabled = true
            cacheMode = WebSettings.LOAD_DEFAULT
            mediaPlaybackRequiresUserGesture = true
            // Hardening: never let web content reach the local filesystem.
            allowFileAccess = false
            allowContentAccess = false
            userAgentString = "$userAgentString TheQuestSDK/${SdkInfo.version} (android)"
        }

        // qs_session is SameSite=None → third-party cookies must be accepted.
        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            setAcceptThirdPartyCookies(webView, true)
        }

        // SECURITY: the JS interface is added ONLY to this WebView, which only ever loads our
        // own offerwall origin.
        webView.addJavascriptInterface(QuestBridge(this), QuestBridge.NAME)
        webView.webViewClient = OfferwallWebViewClient()
        // Without a WebChromeClient, `<input type="file">` taps are silently dropped and no
        // file selector ever opens. This routes them to the permission-free photo picker.
        webView.webChromeClient = OfferwallWebChromeClient()
    }

    private fun registerBackHandler() {
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    val wv = webView
                    if (wv != null && wv.canGoBack()) wv.goBack() else dismiss()
                }
            },
        )
    }

    /** (Re)load the offerwall, running the secure-mode launch provider first if present. */
    private fun startLoad() {
        showLoading()
        val provider = entry?.launchProvider
        if (provider == null) {
            loadOfferwall(token = null)
            return
        }
        lifecycleScope.launch {
            try {
                val token = provider(userId)
                loadOfferwall(token)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "launchProvider failed", e)
                showError()
            }
        }
    }

    private fun loadOfferwall(token: LaunchToken?) {
        val url = LaunchUrlBuilder.build(
            baseUrl = baseUrl,
            appId = appId,
            userId = userId,
            token = token,
            deviceLanguage = deviceLanguage(),
        )
        webView?.loadUrl(url)
    }

    private fun deviceLanguage(): String? =
        resources.configuration.locales[0]?.language // minSdk 24 → locales list is available

    // ── UI state ──────────────────────────────────────────────────────────────

    private fun showLoading() {
        progressBar.visibility = View.VISIBLE
        errorView.visibility = View.GONE
        webView?.visibility = View.VISIBLE
    }

    private fun hideLoading() {
        progressBar.visibility = View.GONE
    }

    private fun showError() {
        progressBar.visibility = View.GONE
        errorView.visibility = View.VISIBLE
        webView?.visibility = View.GONE
    }

    /** Dismiss the offerwall, firing the host [onClose] exactly once. */
    private fun dismiss() {
        fireOnClose()
        if (!isFinishing) finish()
    }

    private fun fireOnClose() {
        if (closeInvoked) return
        closeInvoked = true
        entry?.onClose?.invoke()
    }

    // ── Bridge callbacks (invoked off the UI thread) ────────────────────────────

    override fun onOpenUrl(url: String) {
        runOnUiThread { openExternal(url) }
    }

    override fun onClose() {
        runOnUiThread { dismiss() }
    }

    override fun onReady() {
        runOnUiThread { hideLoading() }
    }

    /**
     * Open an external URL / app deep link. Supports `intent://…` via [Intent.parseUri] with
     * its `browser_fallback_url`. Never navigates the offerwall WebView itself.
     */
    private fun openExternal(url: String) {
        try {
            val intent = if (url.startsWith("intent:")) {
                Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            } else {
                Intent(Intent.ACTION_VIEW, Uri.parse(url))
            }
            try {
                startActivity(intent)
            } catch (e: ActivityNotFoundException) {
                val fallback = if (url.startsWith("intent:")) {
                    intent.getStringExtra("browser_fallback_url")
                } else {
                    null
                }
                if (!fallback.isNullOrEmpty()) {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(fallback)))
                } else {
                    Log.w(TAG, "No activity found to handle openUrl and no fallback")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to open external url", e)
        }
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────────

    override fun onPause() {
        super.onPause()
        webView?.onPause()
        CookieManager.getInstance().flush()
    }

    override fun onResume() {
        super.onResume()
        webView?.onResume()
    }

    override fun onDestroy() {
        // Cover system-initiated finishes too, so onClose always fires.
        if (isFinishing) fireOnClose()
        TheQuestSession.remove(requestId)

        // Release any file chooser still awaiting a result so it isn't delivered to a dead WebView.
        filePathCallback?.onReceiveValue(null)
        filePathCallback = null

        webView?.let { wv ->
            wv.removeJavascriptInterface(QuestBridge.NAME)
            wv.stopLoading()
            wv.webViewClient = WebViewClient()
            (wv.parent as? ViewGroup)?.removeView(wv)
            wv.destroy()
        }
        webView = null

        CookieManager.getInstance().flush()
        super.onDestroy()
    }

    // ── File chooser ────────────────────────────────────────────────────────────

    private inner class OfferwallWebChromeClient : WebChromeClient() {
        override fun onShowFileChooser(
            webView: WebView?,
            callback: ValueCallback<Array<Uri>>?,
            params: FileChooserParams?,
        ): Boolean {
            // A new request supersedes any in-flight one; release the previous input first
            // so it is never left hanging (which would make it un-tappable).
            filePathCallback?.onReceiveValue(null)
            filePathCallback = callback

            return try {
                if (isImageOnly(params?.acceptTypes)) {
                    val request = PickVisualMediaRequest(
                        ActivityResultContracts.PickVisualMedia.ImageOnly,
                    )
                    if (params?.mode == FileChooserParams.MODE_OPEN_MULTIPLE) {
                        pickMultipleImages.launch(request)
                    } else {
                        pickSingleImage.launch(request)
                    }
                } else {
                    pickDocument.launch(params!!.createIntent())
                }
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open file chooser", e)
                deliverFileChooserResult(emptyArray())
                false
            }
        }
    }

    /** Deliver the picked uris (empty on cancel) to the pending WebView callback, once. */
    private fun deliverFileChooserResult(uris: Array<Uri>) {
        filePathCallback?.onReceiveValue(uris)
        filePathCallback = null
    }

    /** True when every declared `accept` type is an image mime — routes to the photo picker. */
    private fun isImageOnly(acceptTypes: Array<String>?): Boolean {
        val types = acceptTypes?.map { it.trim() }?.filter { it.isNotEmpty() } ?: emptyList()
        return types.isNotEmpty() && types.all { it.startsWith("image/") }
    }

    private inner class OfferwallWebViewClient : WebViewClient() {

        override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
            super.onPageStarted(view, url, favicon)
            injectBridgeShim() // native can't inject at document-start; do it as early as possible
        }

        override fun onPageFinished(view: WebView?, url: String?) {
            super.onPageFinished(view, url)
            injectBridgeShim() // fallback guard in case onPageStarted was missed
            hideLoading() // fallback for pages that never call ready()
        }

        override fun onReceivedError(
            view: WebView?,
            request: WebResourceRequest?,
            error: WebResourceError?,
        ) {
            super.onReceivedError(view, request, error)
            if (request?.isForMainFrame == true) {
                runOnUiThread { showError() }
            }
        }

        override fun onRenderProcessGone(
            view: WebView?,
            detail: RenderProcessGoneDetail?,
        ): Boolean {
            // Critical for low-memory devices: the render process died. Tear down and finish
            // gracefully instead of letting the host app crash.
            Log.w(TAG, "WebView render process gone; closing offerwall")
            webView = null
            view?.let { (it.parent as? ViewGroup)?.removeView(it); it.destroy() }
            if (!isFinishing) finish()
            return true
        }
    }

    private fun injectBridgeShim() {
        webView?.evaluateJavascript(bridgeShimJs(), null)
    }

    companion object {
        private const val TAG = "TheQuest"

        const val EXTRA_REQUEST_ID = "world.humanlabs.quest.extra.REQUEST_ID"
        const val EXTRA_APP_ID = "world.humanlabs.quest.extra.APP_ID"
        const val EXTRA_BASE_URL = "world.humanlabs.quest.extra.BASE_URL"
        const val EXTRA_USER_ID = "world.humanlabs.quest.extra.USER_ID"

        /**
         * The `window.TheQuestNative` shim (see `docs/BRIDGE.md` §1). `_post` forwards to the
         * `TheQuestAndroid` `@JavascriptInterface`. Idempotent: skips if already installed.
         */
        private fun bridgeShimJs(): String {
            val version = SdkInfo.version
            return """
                (function () {
                  if (window.TheQuestNative) { return; }
                  function _post(obj) {
                    try { ${QuestBridge.NAME}.postMessage(JSON.stringify(obj)); } catch (e) {}
                  }
                  window.TheQuestNative = {
                    openUrl: function (url) { _post({ type: "openUrl", url: String(url) }); },
                    close: function () { _post({ type: "close" }); },
                    ready: function () { _post({ type: "ready" }); },
                    postMessage: function (obj) { _post(obj); },
                    platform: "android",
                    version: "$version"
                  };
                })();
            """.trimIndent()
        }
    }
}
