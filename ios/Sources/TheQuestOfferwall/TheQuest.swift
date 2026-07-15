import Foundation
import UIKit
import os

/// Errors surfaced while preparing an offerwall launch.
public enum TheQuestError: Error {
    /// The launch URL could not be constructed from the current configuration.
    case invalidLaunchURL
}

/// Entry point for embedding **The Quest** offerwall.
///
/// Configure your app id (and optional base URL) in `Info.plist`, then call
/// ``show(from:userId:launchProvider:onClose:)``:
///
/// ```swift
/// // Standard (unsigned) mode
/// TheQuest.shared.show(from: self, userId: "user-123")
///
/// // Secure mode
/// TheQuest.shared.show(from: self, userId: "user-123") { userId in
///     try await MyBackend.fetchLaunchToken(userId: userId) // -> LaunchToken
/// }
/// ```
public final class TheQuest {

    /// The shared singleton instance.
    public static let shared = TheQuest()

    private let logger = Logger(subsystem: "world.humanlabs.thequest", category: "Offerwall")

    private init() {}

    /// Presents the offerwall full-screen from `presenter`.
    ///
    /// - Parameters:
    ///   - presenter: The view controller to present from.
    ///   - userId: Your identifier for the current user.
    ///   - launchProvider: Optional. `nil` runs standard (unsigned) mode. When provided,
    ///     it is awaited on every `show()` to fetch `{ ts, nonce, sig }` from your backend
    ///     (secure mode) before the launch URL is built. A spinner is shown while awaiting;
    ///     a thrown error surfaces the retry screen.
    ///   - onClose: Optional. Called once when the offerwall is dismissed (header button,
    ///     web `close`, or interactive swipe).
    ///
    /// If `TheQuestAppId` is missing/empty in `Info.plist`, a clear error is logged and the
    /// call is aborted (no crash).
    public func show(
        from presenter: UIViewController,
        userId: String,
        launchProvider: (@Sendable (_ userId: String) async throws -> LaunchToken)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        guard let config = TheQuestConfig.load() else {
            logger.error(
                "Missing or empty '\(TheQuestConfig.appIdKey, privacy: .public)' in Info.plist. Aborting show()."
            )
            return
        }

        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserId.isEmpty else {
            logger.error("show() called with an empty userId. Aborting.")
            return
        }

        let baseURL = config.baseURL
        let appId = config.appId
        let deviceLanguageCode = Locale.preferredLanguages.first

        let resolveURL: @Sendable () async throws -> URL
        if let launchProvider {
            resolveURL = {
                let token = try await launchProvider(trimmedUserId)
                guard let url = LaunchURLBuilder.build(
                    baseURL: baseURL,
                    appId: appId,
                    userId: trimmedUserId,
                    token: token,
                    deviceLanguageCode: deviceLanguageCode
                ) else {
                    throw TheQuestError.invalidLaunchURL
                }
                return url
            }
        } else {
            guard let url = LaunchURLBuilder.build(
                baseURL: baseURL,
                appId: appId,
                userId: trimmedUserId,
                token: nil,
                deviceLanguageCode: deviceLanguageCode
            ) else {
                logger.error("Failed to build the launch URL. Aborting show().")
                return
            }
            resolveURL = { url }
        }

        let present = {
            let controller = OfferwallViewController(
                baseURL: baseURL,
                headerTitle: nil,
                onClose: onClose,
                resolveURL: resolveURL
            )
            presenter.present(controller, animated: true, completion: nil)
        }

        if Thread.isMainThread {
            present()
        } else {
            DispatchQueue.main.async(execute: present)
        }
    }
}
