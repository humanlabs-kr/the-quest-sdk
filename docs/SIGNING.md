# Secure mode — server-side launch signing

Only needed for App IDs flagged **`require_signed_launch`** in the Quest admin. Standard
apps skip this entirely and just call `show(userId)`.

## Why the SDK cannot sign

The launch signature is `HMAC-SHA256(app.secret, message)`. The **app secret is a server
secret** — embedding it in a mobile binary means anyone can extract it and forge launches
for any user. So signing happens on **your backend**; the SDK only receives the result.

## Canonical message

```
message = [app_id, user_id, ts, nonce, locale].join(".")   // locale "" if absent
sig     = hex( HMAC_SHA256(key = app_secret, msg = utf8(message)) )   // lowercase hex
```

- `ts` — unix time; seconds or milliseconds. Valid within ±5 minutes of server time.
- `nonce` — random string, 8–100 chars, unique per launch.
- `locale` — optional (`en` / `id` / `es` / `pt`); default `en`.

## Backend endpoint (example, Node)

```ts
import crypto from "node:crypto";

app.post("/quest/launch-token", authYourUser, (req, res) => {
  const app_id = process.env.QUEST_APP_ID!;
  const app_secret = process.env.QUEST_APP_SECRET!; // server-only
  const user_id = req.user.id;
  const ts = Date.now();
  const nonce = crypto.randomBytes(16).toString("hex");
  const locale = req.user.locale ?? "";
  const message = [app_id, user_id, String(ts), nonce, locale].join(".");
  const sig = crypto.createHmac("sha256", app_secret).update(message).digest("hex");
  res.json({ ts, nonce, sig, locale: locale || undefined });
});
```

## Client wiring

The `launchProvider` you pass to `show()` calls the endpoint above and returns
`{ ts, nonce, sig, locale? }`. The SDK combines it with the baked App ID + user ID to
build the launch URL. Because launches expire (±5 min) the provider is called on **every**
`show()`.
