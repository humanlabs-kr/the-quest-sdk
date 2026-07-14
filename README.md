# The Quest Offerwall SDK

Drop-in SDKs to embed **The Quest** offerwall into your app. The SDK ships a hosted
WebView with a native header — you call **`show()`** and we handle the rest.

- **iOS** (Swift, WKWebView) → CocoaPods `TheQuestOfferwall`
- **Android** (Kotlin, WebView) → Maven Central `world.humanlabs:quest-offerwall`
- **Expo / React Native** (`react-native-webview`) → npm `@thequest/offerwall-expo`

| Platform | Package | Min version |
|----------|---------|-------------|
| iOS | `TheQuestOfferwall` (CocoaPods / SPM) | iOS 15+ |
| Android | `world.humanlabs:quest-offerwall` | minSdk 24 (Android 7.0) |
| Expo | `@thequest/offerwall-expo` | Expo SDK 51+ / RN 0.74+ |

## How it works

1. You get an **App ID** (10 chars) from the Quest admin. It is **not secret** — you bake it
   into your build (Info.plist / AndroidManifest / `app.json extra`).
2. You call `show(userId)`. The SDK opens the offerwall WebView pointed at your environment.
3. The WebView exchanges a signed/unsigned launch for an httpOnly session and renders the
   offerwall in your app's reward unit.
4. The native header's close button (or `TheQuestNative.close()` from web) dismisses the
   screen and fires your optional `onClose`.

## Authentication modes

The offerwall supports two launch modes, chosen **per App ID** in the admin:

- **Standard (default)** — `show(userId)`. No signing. This is how most offerwalls
  (Tapjoy, ironSource, AdGem…) work: the value transfer is protected on the **reward
  postback** (server→your backend, HMAC-signed), not on opening the offerwall.
- **Secure mode (opt-in)** — for apps flagged `require_signed_launch`. You additionally
  pass a `launchProvider` that fetches `{ ts, nonce, sig }` from **your backend** (which
  holds the app secret). The app secret **must never be embedded in the app**.

> Never put your app secret in the mobile app. In secure mode, sign on your server.
> See [`docs/SIGNING.md`](docs/SIGNING.md).

## Environment (staging vs production)

Environment is a **build-time setting**, not a `show()` argument — the offerwall URL is
fixed per build channel. Default is **production**; opt into staging only for QA builds.

| environment  | URL |
|--------------|-----|
| `production` (default) | `https://quest.humanlabs.world` |
| `staging`    | `https://quest.seriesc.dev` |

Set it alongside your App ID:
- iOS: `TheQuestEnvironment` in `Info.plist`
- Android: `world.humanlabs.quest.ENVIRONMENT` `<meta-data>`
- Expo: `extra.theQuest.environment` in `app.json`

## Quick start

See each package's README:
- [`ios/README.md`](ios/README.md)
- [`android/README.md`](android/README.md)
- [`expo/README.md`](expo/README.md)

## Releases & automation

Conventional commits → [release-please](https://github.com/googleapis/release-please)
opens per-package Release PRs. Merging one tags `expo-v*` / `android-v*` / `ios-v*`,
which triggers the matching publish workflow.

Required GitHub Actions **secrets** (never committed — this is a public repo):

| secret | used by |
|--------|---------|
| `NPM_TOKEN` | publish-expo → npm |
| `MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD` | publish-android → Maven Central |
| `SIGNING_KEY`, `SIGNING_KEY_PASSWORD` | publish-android → GPG signing |
| `COCOAPODS_TRUNK_TOKEN` | publish-ios → CocoaPods trunk |

## Repo layout

```
ios/      Swift package + podspec
android/  Gradle library (:sdk)
expo/     TypeScript / react-native-webview wrapper
docs/     BRIDGE.md (JS bridge protocol), SIGNING.md (secure mode)
```

## License

MIT © Humanlabs
