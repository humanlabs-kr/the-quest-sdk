# TheQuestOfferwall (iOS)

Embed **The Quest** offerwall in your iOS app. The SDK hosts the offerwall in a
`WKWebView` with a native header — you call `show()` and we handle the rest.

- **Min iOS:** 15.0
- **Language:** Swift 5.9
- **Dependencies:** none (UIKit + WebKit only)

## Install

### CocoaPods (primary)

```ruby
pod 'TheQuestOfferwall'
```

Then `pod install`.

### Swift Package Manager

The package lives in the `ios/` subdirectory of the repo. Add it by path or as a
local package pointing at `ios/`, e.g. in `Package.swift`:

```swift
.package(url: "https://github.com/humanlabs-kr/the-quest-sdk.git", branch: "main")
```

and depend on the `TheQuestOfferwall` product. (SPM consumers reference the `ios/`
package directory.)

## Configure (Info.plist)

Add your app id (and, optionally, the environment) to your app target's `Info.plist`:

| Key | Type | Required | Values |
|-----|------|----------|--------|
| `TheQuestAppId` | String | ✅ | Your 10-character app id (not secret) |
| `TheQuestEnvironment` | String | — | `production` (default) or `staging` |

```xml
<key>TheQuestAppId</key>
<string>ABCDE12345</string>
<key>TheQuestEnvironment</key>
<string>production</string>
```

> No associated-domains / Universal Links entitlement is required — the offerwall is
> webview-only. External links opened from the offerwall use `UIApplication.open`.

If `TheQuestAppId` is missing or empty, `show()` logs a clear error and returns without
presenting anything (it never crashes).

## Usage

### Standard mode (default)

Most integrations. No signing — the value transfer is protected on the reward postback,
not on opening the offerwall.

```swift
import TheQuestOfferwall

TheQuest.shared.show(from: self, userId: "user-123") {
    print("offerwall closed")
}
```

### Secure mode (`launchProvider`)

For app ids flagged `require_signed_launch`. Pass a `launchProvider` that fetches a
signed launch token from **your backend** (which holds the app secret — never embed it
in the app). It is awaited on every `show()`; a spinner shows while awaiting and a
retry screen appears on failure.

```swift
import TheQuestOfferwall

TheQuest.shared.show(
    from: self,
    userId: "user-123",
    launchProvider: { userId in
        // Call YOUR backend, which signs with the app secret (see docs/SIGNING.md).
        let dto = try await MyAPI.fetchQuestLaunchToken(userId: userId)
        return LaunchToken(ts: dto.ts, nonce: dto.nonce, sig: dto.sig, locale: dto.locale)
    },
    onClose: {
        print("offerwall closed")
    }
)
```

See [`../docs/SIGNING.md`](../docs/SIGNING.md) for the canonical signing message and an
example backend endpoint.

## Behavior notes

- **Environment** is build-time (Info.plist), not a `show()` argument.
- **Locale** is derived from the device and mapped to one of `en` / `id` / `es` / `pt`
  (fallback `en`). In secure mode the locale the backend signed is used verbatim.
- **Close** is triggered by the header ✕ button, the web `TheQuestNative.close()` call,
  or an interactive dismissal — `onClose` fires exactly once.
- External links (`TheQuestNative.openUrl`) open in the OS; the offerwall webview is never
  navigated cross-origin.

## License

MIT © Humanlabs
