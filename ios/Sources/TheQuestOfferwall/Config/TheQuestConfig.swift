import Foundation

/// Build-time configuration read from `Bundle.main`'s `Info.plist`.
///
/// - `TheQuestAppId` (`String`, **required**) — your 10-character app id.
/// - `TheQuestBaseURL` (`String`, optional) — the offerwall base URL. Defaults to production
///   (`https://quest.humanlabs.world`). Set it for staging, self-hosted deployments, or local
///   development (e.g. `http://localhost:5173`).
public struct TheQuestConfig: Sendable {
    /// Info.plist key for the required 10-character app id.
    public static let appIdKey = "TheQuestAppId"
    /// Info.plist key for the optional base URL.
    public static let baseURLKey = "TheQuestBaseURL"

    /// The default (production) offerwall base URL, used when `TheQuestBaseURL` is unset.
    public static let defaultBaseURL = URL(string: "https://quest.humanlabs.world")!

    /// The 10-character app id baked into the host app's build.
    public let appId: String

    /// The resolved offerwall base URL (defaults to production).
    public let baseURL: URL

    /// Creates a configuration explicitly (primarily for testing).
    public init(appId: String, baseURL: URL = TheQuestConfig.defaultBaseURL) {
        self.appId = appId
        self.baseURL = baseURL
    }

    /// Reads configuration from the given bundle's Info.plist.
    ///
    /// - Returns: A validated config, or `nil` when `TheQuestAppId` is missing/empty.
    ///   A missing/empty/invalid `TheQuestBaseURL` falls back to the production URL.
    public static func load(from bundle: Bundle = .main) -> TheQuestConfig? {
        guard
            let rawAppId = bundle.object(forInfoDictionaryKey: appIdKey) as? String
        else {
            return nil
        }
        let appId = rawAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appId.isEmpty else { return nil }

        var baseURL = defaultBaseURL
        if let rawBase = bundle.object(forInfoDictionaryKey: baseURLKey) as? String {
            let trimmed = rawBase.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let parsed = URL(string: trimmed) {
                baseURL = parsed
            }
        }

        return TheQuestConfig(appId: appId, baseURL: baseURL)
    }
}
