package world.humanlabs.quest.config

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/** Target offerwall environment, selected at build time via manifest `<meta-data>`. */
enum class Environment(val baseUrl: String) {
    PRODUCTION("https://quest.humanlabs.world"),
    STAGING("https://quest.seriesc.dev");

    companion object {
        /** Parse a manifest value; anything other than "staging" (case-insensitive) is production. */
        fun from(raw: String?): Environment =
            if (raw?.trim()?.equals("staging", ignoreCase = true) == true) STAGING else PRODUCTION
    }
}

/**
 * Build-time configuration read from the consuming app's `AndroidManifest.xml` `<meta-data>`.
 *
 * ```xml
 * <meta-data android:name="world.humanlabs.quest.APP_ID" android:value="abcd012345" />
 * <meta-data android:name="world.humanlabs.quest.ENVIRONMENT" android:value="production" />
 * ```
 *
 * @property appId       The 10-char App ID from the Quest admin (not secret).
 * @property environment Selected environment (defaults to production).
 */
data class QuestConfig(
    val appId: String,
    val environment: Environment,
) {
    val baseUrl: String get() = environment.baseUrl

    companion object {
        private const val TAG = "TheQuest"
        const val META_APP_ID = "world.humanlabs.quest.APP_ID"
        const val META_ENVIRONMENT = "world.humanlabs.quest.ENVIRONMENT"

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
            val environment = Environment.from(metaData.get(META_ENVIRONMENT)?.toString())
            return QuestConfig(appId = appId, environment = environment)
        }
    }
}
