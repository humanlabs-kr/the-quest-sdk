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
        /// Web asks native to present a permission-free photo picker (bypasses WKWebView's
        /// camera-bearing file panel). Result is returned via `imagesPickedJS`.
        case pickImages(requestId: String, multiple: Bool)

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
            case "pickImages":
                guard let requestId = dict["requestId"] as? String, !requestId.isEmpty else {
                    return nil
                }
                let multiple = (dict["multiple"] as? Bool) ?? false
                return .pickImages(requestId: requestId, multiple: multiple)
            default:
                return nil
            }
        }
    }

    /// JS that delivers picked image data URLs back to the web for `requestId`, over the
    /// reserved `thequest:native` channel (docs/BRIDGE.md §4). Returns `[]` on cancel.
    static func imagesPickedJS(requestId: String, dataURLs: [String]) -> String {
        let payload: [String: Any] = [
            "type": "imagesPicked",
            "requestId": requestId,
            "images": dataURLs,
        ]
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // `json` is machine-generated JSON (a valid JS object literal); safe to interpolate.
        return "window.dispatchEvent(new MessageEvent('thequest:native', { data: \(json) }));"
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
