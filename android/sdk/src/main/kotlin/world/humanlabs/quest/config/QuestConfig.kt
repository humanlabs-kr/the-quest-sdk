package world.humanlabs.quest.config

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Build-time configuration read from the consuming app's `AndroidManifest.xml` `<meta-data>`.
 *
 * ```xml
 * <meta-data android:name="world.humanlabs.quest.APP_ID" android:value="abcd012345" />
 * <meta-data android:name="world.humanlabs.quest.BASE_URL" android:value="https://quest.humanlabs.world" />
 * ```
 *
 * @property appId   The 10-char App ID from the Quest admin (not secret).
 * @property baseUrl The offerwall base URL. Defaults to production; set it for staging,
 *   self-hosted deployments, or local development (e.g. `http://10.0.2.2:5173`).
 */
data class QuestConfig(
    val appId: String,
    val baseUrl: String = DEFAULT_BASE_URL,
) {
    companion object {
        private const val TAG = "TheQuest"

        /** The default (production) offerwall base URL, used when [META_BASE_URL] is unset. */
        const val DEFAULT_BASE_URL = "https://quest.humanlabs.world"

        const val META_APP_ID = "world.humanlabs.quest.APP_ID"
        const val META_BASE_URL = "world.humanlabs.quest.BASE_URL"

        /**
         * Read configuration from the manifest. Returns `null` (and logs) when [META_APP_ID]
         * is missing so callers can no-op instead of crashing the host app.
         */
        fun from(context: Context): QuestConfig? {
            val metaData = try {
                val pm = context.packageManager
                val pkg = context.packageName
                val flags = PackageManager.GET_META_DATA
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(
                        pkg,
                        PackageManager.ApplicationInfoFlags.of(flags.toLong()),
                    ).metaData
                } else {
                    @Suppress("DEPRECATION")
                    pm.getApplicationInfo(pkg, flags).metaData
                }
            } catch (e: PackageManager.NameNotFoundException) {
                Log.e(TAG, "Unable to read application meta-data", e)
                null
            }

            // meta-data values can be parsed as non-string types; coerce defensively.
            @Suppress("DEPRECATION")
            val appId = metaData?.get(META_APP_ID)?.toString()?.trim()
            if (appId.isNullOrEmpty()) {
                Log.e(
                    TAG,
                    "Missing <meta-data android:name=\"$META_APP_ID\"> in AndroidManifest.xml. " +
                        "The Quest offerwall will not open.",
                )
                return null
            }

            @Suppress("DEPRECATION")
            val baseUrl = metaData.get(META_BASE_URL)?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                ?: DEFAULT_BASE_URL
            return QuestConfig(appId = appId, baseUrl = baseUrl)
        }
    }
}
