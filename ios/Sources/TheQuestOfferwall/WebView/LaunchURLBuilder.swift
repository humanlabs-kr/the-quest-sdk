import Foundation

/// Pure, side-effect-free builder for the offerwall launch URL.
///
/// The launch URL is:
/// `{base}/?app_id={appId}&user_id={userId}` plus, **only in secure mode**,
/// `&ts=&nonce=&sig=`, plus `&locale=` (always present). All values are
/// percent-encoded.
///
/// - In **standard mode** (`token == nil`) the locale is derived from the device
///   and mapped to one of the supported locales (`en`/`id`/`es`/`pt`, fallback `en`).
/// - In **secure mode** (`token != nil`) the locale sent on the URL is exactly the
///   locale the backend signed (`token.locale`, or empty when it signed no locale),
///   so the HMAC signature stays valid.
public enum LaunchURLBuilder {
    /// Locales the offerwall renders; anything else falls back to `en`.
    public static let supportedLocales: Set<String> = ["en", "id", "es", "pt"]

    /// The locale used when the device locale is missing or unsupported.
    public static let fallbackLocale = "en"

    /// Maps a raw locale/language identifier (e.g. `"pt-BR"`, `"es_ES"`, `"fr"`) to one
    /// of the supported locales, falling back to `en`.
    public static func normalizedLocale(from raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return fallbackLocale }
        let language = raw
            .lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init) ?? ""
        return supportedLocales.contains(language) ? language : fallbackLocale
    }

    /// Builds the offerwall launch URL.
    ///
    /// - Parameters:
    ///   - baseURL: Environment base URL (no query/path).
    ///   - appId: The 10-character app id.
    ///   - userId: The host-provided user identifier.
    ///   - token: Secure-mode launch token, or `nil` for standard mode.
    ///   - deviceLanguageCode: Raw device locale/language identifier used in standard mode.
    /// - Returns: The fully-encoded launch URL, or `nil` if a URL cannot be formed.
    public static func build(
        baseURL: URL,
        appId: String,
        userId: String,
        token: LaunchToken?,
        deviceLanguageCode: String?
    ) -> URL? {
        var pairs: [(String, String)] = [
            ("app_id", appId),
            ("user_id", userId)
        ]

        let locale: String
        if let token {
            pairs.append(("ts", token.ts))
            pairs.append(("nonce", token.nonce))
            pairs.append(("sig", token.sig))
            // Must equal exactly what the backend signed (empty when it signed no locale).
            locale = token.locale ?? ""
        } else {
            locale = normalizedLocale(from: deviceLanguageCode)
        }
        pairs.append(("locale", locale))

        let query = pairs
            .map { "\(encode($0.0))=\(encode($0.1))" }
            .joined(separator: "&")

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = "/"
        components.percentEncodedQuery = query
        return components.url
    }

    /// Percent-encodes a value, escaping everything outside the URL unreserved set
    /// (`A–Z a–z 0–9 - . _ ~`). This guarantees `+`, spaces, `&`, `=`, etc. are escaped.
    private static func encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
