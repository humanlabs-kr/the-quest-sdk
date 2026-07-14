import Foundation

/// The native ↔ web JS bridge for iOS, per `docs/BRIDGE.md`.
///
/// The injected script installs `window.TheQuestNative` at document start and routes
/// every message through the `theQuestNative` `WKScriptMessageHandler`.
enum BridgeScript {
    /// The name of the `WKScriptMessageHandler` the web posts to.
    static let messageHandlerName = "theQuestNative"

    /// A parsed message sent from web → native.
    enum Message: Equatable {
        case openUrl(URL)
        case close
        case ready

        /// Parses a message body delivered by `WKScriptMessage`.
        ///
        /// iOS delivers `postMessage(obj)` bodies as `NSDictionary` (bridged to
        /// `[String: Any]`). Unknown or malformed messages return `nil`.
        static func parse(_ body: Any) -> Message? {
            guard let dict = body as? [String: Any],
                  let type = dict["type"] as? String else {
                return nil
            }
            switch type {
            case "openUrl":
                guard let raw = dict["url"] as? String,
                      let url = URL(string: raw) else {
                    return nil
                }
                return .openUrl(url)
            case "close":
                return .close
            case "ready":
                return .ready
            default:
                return nil
            }
        }
    }

    /// The JavaScript injected at `.atDocumentStart`. Mirrors the shared bridge contract:
    /// `_post` uses `window.webkit.messageHandlers.theQuestNative.postMessage(obj)`.
    static func userScriptSource(version: String) -> String {
        // `version` is our own SDKInfo.version (semver, no user input) — safe to interpolate.
        return """
        (function () {
          function _post(obj) {
            try {
              window.webkit.messageHandlers.\(messageHandlerName).postMessage(obj);
            } catch (e) {}
          }
          window.TheQuestNative = {
            openUrl: function (url) { _post({ type: "openUrl", url: String(url) }); },
            close: function () { _post({ type: "close" }); },
            ready: function () { _post({ type: "ready" }); },
            postMessage: function (obj) { _post(obj); },
            platform: "ios",
            version: "\(version)"
          };
        })();
        """
    }
}
