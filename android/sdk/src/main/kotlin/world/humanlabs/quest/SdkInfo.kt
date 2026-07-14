package world.humanlabs.quest

/**
 * Source-of-truth fallback for the SDK version, kept in sync by release-please.
 *
 * The build normally exposes the version via [BuildConfig.SDK_VERSION]; this constant is
 * a compile-time fallback used when [BuildConfig] is unavailable (e.g. plain unit tests).
 */
internal const val SDK_VERSION_FALLBACK = "0.2.0" // x-release-please-version

/** Resolved SDK semantic version (e.g. `0.1.0`). */
internal object SdkInfo {
    val version: String = runCatching { BuildConfig.SDK_VERSION }
        .getOrDefault(SDK_VERSION_FALLBACK)
}
