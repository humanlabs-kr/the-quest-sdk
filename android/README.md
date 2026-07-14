# The Quest Offerwall — Android SDK

Embed **The Quest** offerwall in your Android app. The SDK hosts the offerwall in a
WebView inside a dedicated full-screen Activity with a native header — you call
`TheQuest.show(...)` and we handle the rest.

- **Language:** Kotlin
- **Min SDK:** 24 (Android 7.0)
- **Artifact:** `world.humanlabs:quest-offerwall`

## Install

```kotlin
// build.gradle.kts (app module)
dependencies {
    implementation("world.humanlabs:quest-offerwall:0.1.0")
}
```

Published to Maven Central, so `mavenCentral()` in your repositories is all you need.

## Configure

Your **App ID** (10 chars, from the Quest admin) and the environment are build-time
settings. Add them to your app's `AndroidManifest.xml` inside `<application>`:

```xml
<application ...>
    <meta-data
        android:name="world.humanlabs.quest.APP_ID"
        android:value="abcd012345" />

    <!-- optional: "production" (default) or "staging" -->
    <meta-data
        android:name="world.humanlabs.quest.ENVIRONMENT"
        android:value="production" />
</application>
```

| Environment | URL |
|-------------|-----|
| `production` (default) | `https://quest.humanlabs.world` |
| `staging` | `https://quest.seriesc.dev` |

The App ID is **not secret** — it is safe to bake into your build. If it is missing, the
SDK logs an error and no-ops (it never crashes your app).

## Usage

### Standard mode (default)

Most offerwalls work this way — the value transfer is protected on the reward postback
(server → your backend), not on opening the offerwall.

```kotlin
TheQuest.show(
    context = this,
    userId = currentUser.id,
    onClose = { /* optional: user closed the offerwall */ },
)
```

### Secure mode (opt-in)

Only for App IDs flagged `require_signed_launch` in the admin. You pass a `launchProvider`
that fetches `{ ts, nonce, sig }` from **your backend** (which holds the app secret). The
app secret must **never** be embedded in the app — see [`../docs/SIGNING.md`](../docs/SIGNING.md).

```kotlin
TheQuest.show(
    context = this,
    userId = currentUser.id,
    launchProvider = { userId ->
        // Call YOUR backend, which signs with the app secret and returns the token.
        val res = api.getQuestLaunchToken(userId) // suspend function
        LaunchToken(ts = res.ts, nonce = res.nonce, sig = res.sig, locale = res.locale)
    },
    onClose = { /* ... */ },
)
```

The provider is `suspend` and is called on **every** `show()` because launches expire
(±5 minutes). While it runs, the offerwall screen shows a spinner; on failure it shows a
retry button.

## Locale

The offerwall renders in `en` / `id` / `es` / `pt`. In standard mode the device locale is
mapped automatically (fallback `en`). In secure mode the locale returned by your backend
is used, so it stays consistent with the signed launch.

## Low-end device notes

This SDK is built to run well on low-end hardware:

- **No Compose** — the header is a plain XML `LinearLayout`; only the WebView is heavy.
- A **single** WebView is created and destroyed cleanly (removed from the tree, JS
  interface detached, `destroy()` called) to avoid leaks.
- `onRenderProcessGone` is handled: if the WebView render process is killed under memory
  pressure, the offerwall closes gracefully instead of crashing your app.
- Conservative WebView settings (default cache mode, media requires a user gesture, file &
  content access disabled).

## Security

- The JS bridge (`window.TheQuestNative`) exposes only `openUrl` / `close` / `ready` — no
  storage, files, contacts, or arbitrary intents. See [`../docs/BRIDGE.md`](../docs/BRIDGE.md).
- The `@JavascriptInterface` is added **only** to the offerwall WebView, which only ever
  loads our own origin.
- No app secret ever crosses the bridge; signing happens on your backend.

## License

MIT © Humanlabs
