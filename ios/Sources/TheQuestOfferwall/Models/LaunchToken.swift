import Foundation

/// A short-lived, server-signed launch credential used in **secure mode**.
///
/// The values are produced by your backend (which holds the app secret) — see
/// `docs/SIGNING.md`. The SDK never signs launches itself; it only forwards the
/// signature you provide when building the offerwall launch URL.
public struct LaunchToken: Sendable {
    /// Unix timestamp (seconds or milliseconds) of when the signature was produced.
    /// Valid within ±5 minutes of server time.
    public let ts: String

    /// Random, per-launch nonce (8–100 characters).
    public let nonce: String

    /// Lowercase hex `HMAC-SHA256(app_secret, message)` signature.
    public let sig: String

    /// Optional locale (`en` / `id` / `es` / `pt`) that was included in the signed message.
    /// When present it overrides the device-derived locale so the signature stays valid.
    public let locale: String?

    /// Creates a launch token from values returned by your signing backend.
    public init(ts: String, nonce: String, sig: String, locale: String? = nil) {
        self.ts = ts
        self.nonce = nonce
        self.sig = sig
        self.locale = locale
    }
}
