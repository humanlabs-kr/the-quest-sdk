package world.humanlabs.quest.internal

import android.net.Uri
import world.humanlabs.quest.models.LaunchToken

/**
 * Pure, side-effect-free builder for the offerwall launch URL. Kept isolated from Android
 * lifecycle/UI so it can be unit-tested directly.
 *
 * Produces:
 * ```
 * {base}/?app_id={appId}&user_id={userId}[&ts=&nonce=&sig=]&locale={locale}
 * ```
 * Standard mode omits `ts/nonce/sig`; secure mode includes them and uses the exact locale
 * that was signed (see `docs/SIGNING.md`). `locale` is always present.
 */
internal object LaunchUrlBuilder {

    /** Locales the offerwall web app renders; everything else falls back to English. */
    private val SUPPORTED = setOf("en", "id", "es", "pt")

    /**
     * Map a device language tag (e.g. `en`, `en-US`, `pt_BR`) to a supported offerwall
     * locale, falling back to `en`. Handles Java's legacy `in` code for Indonesian.
     */
    fun mapLocale(language: String?): String {
        val lang = language
            ?.trim()
            ?.lowercase()
            ?.substringBefore('-')
            ?.substringBefore('_')
            ?: return "en"
        val normalized = if (lang == "in") "id" else lang // legacy JDK code for Indonesian
        return if (normalized in SUPPORTED) normalized else "en"
    }

    /**
     * Build the launch URL.
     *
     * @param baseUrl        Environment base, e.g. `https://quest.humanlabs.world`.
     * @param appId          The baked App ID.
     * @param userId         The end user's ID in the host app.
     * @param token          Secure-mode signing result, or `null` for standard mode.
     * @param deviceLanguage Device language tag, used only in standard mode for the locale.
     */
    fun build(
        baseUrl: String,
        appId: String,
        userId: String,
        token: LaunchToken?,
        deviceLanguage: String?,
    ): String {
        val builder = Uri.parse(baseUrl).buildUpon()
            // Ensure the path is exactly "/" so query params attach to the root document.
            .path("/")
            .appendQueryParameter("app_id", appId)
            .appendQueryParameter("user_id", userId)

        val locale: String
        if (token != null) {
            builder
                .appendQueryParameter("ts", token.ts)
                .appendQueryParameter("nonce", token.nonce)
                .appendQueryParameter("sig", token.sig)
            // In secure mode the locale MUST match what the backend signed. The message
            // uses "" when locale is absent, so mirror that exactly here.
            locale = token.locale ?: ""
        } else {
            locale = mapLocale(deviceLanguage)
        }

        builder.appendQueryParameter("locale", locale)
        return builder.build().toString()
    }
}
