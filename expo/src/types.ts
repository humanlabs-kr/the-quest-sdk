/** Which hosted offerwall environment the build points at. */
export type Environment = "production" | "staging";

/** Locales the offerwall renders in. Everything else falls back to `en`. */
export type QuestLocale = "en" | "id" | "es" | "pt";

/**
 * Build-time configuration, read from `expo-constants`
 * (`Constants.expoConfig.extra.theQuest`). The App ID is NOT secret and is baked
 * into your build; the environment is fixed per build channel.
 */
export interface TheQuestConfig {
  /** 10-character App ID from the Quest admin. */
  appId: string;
  /** Defaults to `"production"`. */
  environment?: Environment;
}

/**
 * Result of a secure-mode launch signing request. Produced by YOUR backend
 * (which holds the app secret) — never signed on-device. See docs/SIGNING.md.
 */
export interface LaunchToken {
  /** Unix time, seconds or milliseconds. Valid within ±5 minutes of server time. */
  ts: string | number;
  /** Random string, unique per launch (8–100 chars). */
  nonce: string;
  /** Lowercase hex HMAC-SHA256 signature. */
  sig: string;
  /** The locale the signature was computed over, if any. */
  locale?: string;
}

/**
 * Called on every `show()` in secure mode. Fetches a fresh {@link LaunchToken}
 * from your backend for the given user. Omit for standard (unsigned) mode.
 */
export type LaunchProvider = (userId: string) => Promise<LaunchToken>;

/** Options passed to {@link TheQuest.show}. */
export interface ShowOptions {
  /** Your app's stable identifier for the current user. */
  userId: string;
  /**
   * Secure mode only. Provide to sign launches on your backend; omit for the
   * standard (unsigned) flow used by most offerwalls.
   */
  launchProvider?: LaunchProvider;
  /** Fired once when the offerwall is dismissed. */
  onClose?: () => void;
  /** Optional locale override (`en` / `id` / `es` / `pt`). Defaults to the device locale. */
  locale?: string;
}
