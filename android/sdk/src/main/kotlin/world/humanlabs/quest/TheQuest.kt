package world.humanlabs.quest

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import world.humanlabs.quest.config.QuestConfig
import world.humanlabs.quest.models.LaunchToken
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Public entry point for The Quest offerwall SDK.
 *
 * Configure your App ID and (optionally) the environment in your app's `AndroidManifest.xml`:
 * ```xml
 * <meta-data android:name="world.humanlabs.quest.APP_ID" android:value="abcd012345" />
 * <meta-data android:name="world.humanlabs.quest.ENVIRONMENT" android:value="production" />
 * ```
 * then call [show].
 */
object TheQuest {

    private const val TAG = "TheQuest"

    /**
     * Open the offerwall.
     *
     * @param context        Any [Context] (Activity preferred). Not retained beyond this call.
     * @param userId         The end user's ID in your app. Must be non-blank.
     * @param launchProvider `null` for **standard** (unsigned) mode. In **secure** mode, a
     *   suspending function that calls your backend and returns a [LaunchToken]. It is invoked
     *   on every [show] because launches expire (see `docs/SIGNING.md`).
     * @param onClose        Optional callback fired when the offerwall is dismissed.
     */
    @JvmStatic
    @JvmOverloads
    fun show(
        context: Context,
        userId: String,
        launchProvider: (suspend (userId: String) -> LaunchToken)? = null,
        onClose: (() -> Unit)? = null,
    ) {
        val config = QuestConfig.from(context) ?: return // logs on missing App ID

        if (userId.isBlank()) {
            Log.e(TAG, "show() called with a blank userId; ignoring.")
            return
        }

        val requestId = UUID.randomUUID().toString()
        TheQuestSession.put(
            requestId,
            TheQuestSession.Entry(launchProvider = launchProvider, onClose = onClose),
        )

        val intent = Intent(context, OfferwallActivity::class.java).apply {
            putExtra(OfferwallActivity.EXTRA_REQUEST_ID, requestId)
            putExtra(OfferwallActivity.EXTRA_APP_ID, config.appId)
            putExtra(OfferwallActivity.EXTRA_BASE_URL, config.baseUrl)
            putExtra(OfferwallActivity.EXTRA_USER_ID, userId)
            // A non-Activity context (e.g. Application) needs a new task to launch an Activity.
            if (context !is Activity) addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Clean up the session if the Activity could not be started.
            TheQuestSession.remove(requestId)
            Log.e(TAG, "Failed to start the offerwall Activity", e)
        }
    }
}

/**
 * Internal holder for the non-Parcelable pieces of a [TheQuest.show] call (the suspending
 * launch provider and the close callback), keyed by a request id passed to the Activity via
 * an Intent extra. Entries are removed when the Activity finishes to avoid leaks.
 */
internal object TheQuestSession {

    /** Callbacks/providers for one offerwall launch. */
    class Entry(
        val launchProvider: (suspend (userId: String) -> LaunchToken)?,
        val onClose: (() -> Unit)?,
    )

    private val entries = ConcurrentHashMap<String, Entry>()

    fun put(requestId: String, entry: Entry) {
        entries[requestId] = entry
    }

    fun get(requestId: String?): Entry? = requestId?.let { entries[it] }

    fun remove(requestId: String?) {
        requestId?.let { entries.remove(it) }
    }
}
