package world.humanlabs.quest.models

/**
 * Result of a server-side launch signing call (secure mode).
 *
 * In secure mode your backend signs the launch with the app secret and returns these
 * fields. The SDK combines them with the baked App ID + user ID to build the launch URL.
 * The app secret itself must **never** be embedded in the app — see `docs/SIGNING.md`.
 *
 * @property ts     Unix time (seconds or milliseconds) used in the signed message.
 * @property nonce  Random string, unique per launch (8–100 chars).
 * @property sig    Lowercase hex `HMAC-SHA256(app_secret, message)`.
 * @property locale Optional locale (`en` / `id` / `es` / `pt`) that was signed.
 */
data class LaunchToken(
    val ts: String,
    val nonce: String,
    val sig: String,
    val locale: String? = null,
)
