import Foundation

/// The Quest environment (build channel). Selected at build time via the
/// `TheQuestEnvironment` Info.plist key; it is never a runtime `show()` argument.
public enum TheQuestEnvironment: String, Sendable {
    case production
    case staging

    /// The offerwall base URL for this environment.
    public var baseURL: URL {
        switch self {
        case .production:
            return URL(string: "https://quest.humanlabs.world")!
        case .staging:
            return URL(string: "https://quest.seriesc.dev")!
        }
    }
}

/// Build-time configuration read from `Bundle.main`'s `Info.plist`.
///
/// - `TheQuestAppId` (`String`, **required**) — your 10-character app id.
/// - `TheQuestEnvironment` (`String`, optional) — `"production"` (default) or `"staging"`.
public struct TheQuestConfig: Sendable {
    /// Info.plist key for the required 10-character app id.
    public static let appIdKey = "TheQuestAppId"
    /// Info.plist key for the optional environment selector.
    public static let environmentKey = "TheQuestEnvironment"

    /// The 10-character app id baked into the host app's build.
    public let appId: String

    /// The resolved environment (defaults to `.production`).
    public let environment: TheQuestEnvironment

    /// The offerwall base URL for the resolved environment.
    public var baseURL: URL { environment.baseURL }

    /// Creates a configuration explicitly (primarily for testing).
    public init(appId: String, environment: TheQuestEnvironment = .production) {
        self.appId = appId
        self.environment = environment
    }

    /// Reads configuration from the given bundle's Info.plist.
    ///
    /// - Returns: A validated config, or `nil` when `TheQuestAppId` is missing/empty.
    ///   An unrecognized `TheQuestEnvironment` value falls back to `.production`.
    public static func load(from bundle: Bundle = .main) -> TheQuestConfig? {
        guard
            let rawAppId = bundle.object(forInfoDictionaryKey: appIdKey) as? String
        else {
            return nil
        }
        let appId = rawAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appId.isEmpty else { return nil }

        let environment: TheQuestEnvironment
        if let rawEnv = bundle.object(forInfoDictionaryKey: environmentKey) as? String,
           let parsed = TheQuestEnvironment(
               rawValue: rawEnv.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
           ) {
            environment = parsed
        } else {
            environment = .production
        }

        return TheQuestConfig(appId: appId, environment: environment)
    }
}
