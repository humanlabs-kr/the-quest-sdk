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
| `pickImages` | `{ requestId, multiple }` | Present a **permission-free** photo picker and return the picked images to the web as `data:` URLs via the `imagesPicked` reply (§4). See §7. |

Transport per platform:
- **iOS**: `WKScriptMessageHandler` named `theQuestNative`; `_post` → `window.webkit.messageHandlers.theQuestNative.postMessage(obj)`.
- **Android**: `@JavascriptInterface` object exposed as `TheQuestAndroid`; `_post` → `TheQuestAndroid.postMessage(JSON.stringify(obj))`.
- **Expo**: `react-native-webview` `onMessage`; `_post` → `window.ReactNativeWebView.postMessage(JSON.stringify(obj))`.

## 4. Native → Web messages

Native pushes events by evaluating (on the offerwall WebView):
```js
window.dispatchEvent(new MessageEvent("thequest:native", { data: { type, ... } }));
```
The web listens with `window.addEventListener("thequest:native", (e) => e.data)`.

| type          | payload                    | when                                                     |
|---------------|----------------------------|----------------------------------------------------------|
| `imagesPicked`| `{ requestId, images }`    | Reply to `pickImages` (§7). `images` is a `data:` URL array (empty on cancel); `requestId` echoes the request. |

Reserved for future use: e.g. `type: "resume"` when the app returns to foreground.

## 5. `openUrl` native rules

- **iOS**: `UIApplication.shared.open(url)`. Universal Links resolve to the target app if installed.
- **Android**: `Intent(ACTION_VIEW, uri)`. Supports `intent://…#Intent;…;end` with `S.browser_fallback_url`. Wrap in `try/catch` (`ActivityNotFoundException`) → fall back to the fallback URL or a browser.
- **Expo**: `Linking.openURL(url)` (falls back to `expo-web-browser` for http(s) if desired).
- The offerwall WebView is **never** navigated cross-origin by `openUrl`; it only ever hosts `quest.humanlabs.world` / `quest.seriesc.dev`.

## 6. Security notes (PUBLIC repo)

- The bridge only exposes `openUrl` / `close` / `ready` / `pickImages`. It does **not** expose
  native storage, contacts, the filesystem, or arbitrary intents. `pickImages` only ever presents
  the OS photo picker and returns user-selected images — it cannot read arbitrary files.
- The Android `@JavascriptInterface` is added **only** to the offerwall WebView loading our own
  origin — never to arbitrary content.
- No `app.secret` or credential ever crosses the bridge. Signing (secure mode) happens on the
  integrator backend; the SDK only ever receives `{ ts, nonce, sig }`.

## 7. `pickImages` — permission-free image selection

The offerwall lets users attach screenshots (`<input type="file" accept="image/*">`). Relying on
the WebView's built-in file panel is a problem on iOS: WKWebView always offers a **camera** option
that **crashes the host app** when it lacks `NSCameraUsageDescription` — and the offerwall never
needs the camera. There is no public API to remove that option.

So the web bypasses the native file panel and drives a native photo picker over the bridge:

1. Web (only inside a **non-Android** SDK webview, i.e. iOS) posts
   `{ type: "pickImages", requestId, multiple }` instead of opening the `<input>`.
2. Native presents the **out-of-process, permission-free** picker — `PHPickerViewController` (iOS),
   `expo-image-picker` library flow (Expo) — filtered to images, no camera, no permission prompt.
3. Native downscales/encodes each pick to a `data:image/jpeg;base64,…` URL and replies with
   `imagesPicked` (§4). The web rebuilds `File`s and runs its normal webp-convert + upload path.

**Android** does *not* use this path: its `WebChromeClient.onShowFileChooser` already routes the
plain `<input>` to the system Photo Picker (`PickVisualMedia`) — gallery only, no camera, no
permission. Web detection: `!!window.TheQuestNative && !/Android/i.test(navigator.userAgent)`.
