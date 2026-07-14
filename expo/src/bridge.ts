import { SDK_VERSION } from "./version";

/**
 * Injected at document start (`injectedJavaScriptBeforeContentLoaded`). Exposes
 * `window.TheQuestNative` so the offerwall web app can ask the native layer to
 * open external links, close the screen, or signal first paint.
 *
 * Kept identical in shape across the iOS / Android / Expo SDKs — see
 * docs/BRIDGE.md (the single source of truth for this protocol).
 */
export const BRIDGE_SHIM = `(function () {
  try {
    function _post(obj) {
      if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
        window.ReactNativeWebView.postMessage(JSON.stringify(obj));
      }
    }
    window.TheQuestNative = {
      openUrl: function (url) { _post({ type: "openUrl", url: String(url) }); },
      close: function () { _post({ type: "close" }); },
      ready: function () { _post({ type: "ready" }); },
      postMessage: function (obj) { _post(obj); },
      platform: "expo",
      version: ${JSON.stringify(SDK_VERSION)}
    };
  } catch (e) {}
  true;
})();
true;`;

/** Web → native messages. See docs/BRIDGE.md §3. */
export type BridgeMessage =
  | { type: "openUrl"; url: string }
  | { type: "close" }
  | { type: "ready" }
  | { type: string; [key: string]: unknown };

/** Safely parses a `postMessage` payload into a {@link BridgeMessage}. */
export function parseBridgeMessage(data: unknown): BridgeMessage | null {
  if (typeof data !== "string") return null;
  try {
    const parsed = JSON.parse(data) as unknown;
    if (
      parsed &&
      typeof parsed === "object" &&
      typeof (parsed as { type?: unknown }).type === "string"
    ) {
      return parsed as BridgeMessage;
    }
  } catch {
    // Ignore non-JSON messages from arbitrary page scripts.
  }
  return null;
}
