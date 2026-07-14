# The Quest — Native ↔ Web JS Bridge Protocol

This is the **single source of truth** for the JavaScript bridge shared by the iOS,
Android, and Expo SDKs and by the offerwall web app (`apps/web`).

The SDK hosts the offerwall in a WebView. Deep-linking to external / social apps is
unreliable from a raw WebView, so the SDK injects a small bridge the web calls to ask
the **native** layer to perform those actions.

## 1. Injected global (all platforms)

At **document start**, every SDK injects this shim so the web can call one uniform API:

```js
window.TheQuestNative = {
  // Open an external URL / app deep link via the native OS (reliable, user-gesture safe).
  openUrl: function (url) { _post({ type: "openUrl", url: String(url) }); },
  // Ask the host to close the offerwall (same as the native header close button).
  close: function () { _post({ type: "close" }); },
  // Web signals it has finished first paint — native hides its loading spinner.
  ready: function () { _post({ type: "ready" }); },
  // Escape hatch for future messages.
  postMessage: function (obj) { _post(obj); },
  // Populated by the SDK so the web can feature-detect + version-gate.
  platform: "ios" | "android" | "expo",
  version: "<sdk semver>"
};
```

`_post` is platform-specific (see §3) but the **message shapes are identical**.

## 2. UserAgent detection

Every SDK appends a token to the WebView UserAgent so the web can detect it is running
inside the native SDK (and enable bridge-based deep-linking instead of web fallbacks):

```
TheQuestSDK/<semver> (<platform>)      e.g.  TheQuestSDK/0.1.0 (android)
```

Web detection (in `apps/web`):
```ts
const inSdk = typeof window !== "undefined" &&
  (/TheQuestSDK\//.test(navigator.userAgent) || !!window.TheQuestNative);
```

## 3. Web → Native messages

All messages are JSON objects with a `type` field.

| type      | payload         | native behavior                                              |
|-----------|-----------------|-------------------------------------------------------------|
| `openUrl` | `{ url }`       | Open `url` in the external app/browser (see §5). Never navigates the offerwall WebView itself. |
| `close`   | —               | Dismiss the offerwall screen, fire host `onClose`.          |
| `ready`   | —               | Hide the native loading spinner.                            |

Transport per platform:
- **iOS**: `WKScriptMessageHandler` named `theQuestNative`; `_post` → `window.webkit.messageHandlers.theQuestNative.postMessage(obj)`.
- **Android**: `@JavascriptInterface` object exposed as `TheQuestAndroid`; `_post` → `TheQuestAndroid.postMessage(JSON.stringify(obj))`.
- **Expo**: `react-native-webview` `onMessage`; `_post` → `window.ReactNativeWebView.postMessage(JSON.stringify(obj))`.

## 4. Native → Web messages (optional, reserved)

Native may push events by evaluating:
```js
window.dispatchEvent(new MessageEvent("thequest:native", { data: { type, ... } }));
```
Reserved for future use (e.g. `type: "resume"` when the app returns to foreground).

## 5. `openUrl` native rules

- **iOS**: `UIApplication.shared.open(url)`. Universal Links resolve to the target app if installed.
- **Android**: `Intent(ACTION_VIEW, uri)`. Supports `intent://…#Intent;…;end` with `S.browser_fallback_url`. Wrap in `try/catch` (`ActivityNotFoundException`) → fall back to the fallback URL or a browser.
- **Expo**: `Linking.openURL(url)` (falls back to `expo-web-browser` for http(s) if desired).
- The offerwall WebView is **never** navigated cross-origin by `openUrl`; it only ever hosts `quest.humanlabs.world` / `quest.seriesc.dev`.

## 6. Security notes (PUBLIC repo)

- The bridge only exposes `openUrl` / `close` / `ready`. It does **not** expose native storage,
  contacts, files, or arbitrary intents.
- The Android `@JavascriptInterface` is added **only** to the offerwall WebView loading our own
  origin — never to arbitrary content.
- No `app.secret` or credential ever crosses the bridge. Signing (secure mode) happens on the
  integrator backend; the SDK only ever receives `{ ts, nonce, sig }`.
