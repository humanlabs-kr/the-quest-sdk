# @humanlabs-kr/quest-offerwall-expo

Drop-in **Expo / React Native** SDK to embed **The Quest** offerwall in a
full-screen WebView with a native header. You call `show()` — we host the rest.

- Pure JS/TS wrapper around [`react-native-webview`](https://github.com/react-native-webview/react-native-webview) (no custom native module).
- Expo SDK 51+ / React Native 0.74+.

## Install

```sh
npx expo install @humanlabs-kr/quest-offerwall-expo react-native-webview expo-constants expo-linking expo-localization
```

## Configure (build-time)

Your **App ID** (10 chars) comes from the Quest admin. It is **not secret** — bake
it into your build. The offerwall base URL defaults to **production**; override it
only for staging QA, a self-hosted deployment, or local development.

| baseUrl | when |
|---------|------|
| _(unset)_ / `https://quest.humanlabs.world` | production (default) |
| `https://quest.seriesc.dev` | staging QA |
| `http://localhost:5173` | local development |

**Option A — `extra.theQuest` (manual):**

```json
{
  "expo": {
    "extra": {
      "theQuest": { "appId": "abc1234567" }
    }
  }
}
```

**Option B — config plugin (convenience):**

```json
{
  "expo": {
    "plugins": [
      ["@humanlabs-kr/quest-offerwall-expo", { "appId": "abc1234567" }]
    ]
  }
}
```

Both write to `extra.theQuest`; pick whichever you prefer.

## Usage

### 1. Mount the provider once at your app root

Required — it hosts the imperative modal so you can call `show()` from anywhere.

```tsx
import { TheQuestProvider } from "@humanlabs-kr/quest-offerwall-expo";

export default function App() {
  return (
    <TheQuestProvider>
      {/* your navigation / screens */}
    </TheQuestProvider>
  );
}
```

### 2. Standard (unsigned) mode

This is how most offerwalls work — the value transfer is protected on the reward
**postback** (server → your backend), not on opening the offerwall.

```tsx
import { TheQuest } from "@humanlabs-kr/quest-offerwall-expo";

async function openOfferwall(userId: string) {
  await TheQuest.show({
    userId,
    onClose: () => console.log("offerwall closed"),
  });
  // resolves once the offerwall is dismissed
}
```

### 3. Secure mode (opt-in)

Only for App IDs flagged `require_signed_launch`. You pass a `launchProvider`
that fetches `{ ts, nonce, sig }` from **your backend**, which holds the app
secret.

> **Never embed your app secret in the app.** Sign on your server.
> See [`docs/SIGNING.md`](https://github.com/humanlabs-kr/the-quest-sdk/blob/main/docs/SIGNING.md).

```tsx
import { TheQuest, type LaunchToken } from "@humanlabs-kr/quest-offerwall-expo";

async function fetchLaunchToken(userId: string): Promise<LaunchToken> {
  const res = await fetch("https://api.yourapp.com/quest/launch-token", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${yourSessionToken}` },
    body: JSON.stringify({ userId }),
  });
  if (!res.ok) throw new Error(`launch-token failed: ${res.status}`);
  return res.json(); // { ts, nonce, sig, locale? }
}

await TheQuest.show({ userId, launchProvider: fetchLaunchToken });
```

The provider is called on **every** `show()` because launches expire (±5 min).

## API

```ts
function TheQuestProvider(props: { children: React.ReactNode }): JSX.Element;

const TheQuest: {
  show(options: {
    userId: string;
    launchProvider?: (userId: string) => Promise<LaunchToken>;
    onClose?: () => void;
    locale?: string; // "en" | "id" | "es" | "pt" (falls back to device locale, then "en")
  }): Promise<void>; // resolves when the offerwall closes
};

interface LaunchToken {
  ts: string | number;
  nonce: string;
  sig: string;
  locale?: string;
}
```

## How it works

1. `show()` builds the launch URL for your baked App ID + base URL and opens a
   full-screen modal with a native header (close button) and a `WebView`.
2. The WebView exchanges the (signed/unsigned) launch for an httpOnly session and
   renders the offerwall.
3. External offer links go through the native bridge (`openUrl` → `Linking`) so
   deep links resolve reliably; the offerwall WebView itself never navigates
   cross-origin.
4. The close button (or `close()` from web) dismisses the screen and fires your
   `onClose`; `show()` resolves.

See [`docs/BRIDGE.md`](https://github.com/humanlabs-kr/the-quest-sdk/blob/main/docs/BRIDGE.md)
for the native ↔ web bridge protocol.

## License

MIT © Humanlabs
