import type { LaunchToken, QuestLocale } from "./types";

const SUPPORTED_LOCALES: readonly QuestLocale[] = ["en", "id", "es", "pt"];

/**
 * Maps an arbitrary locale/language tag (e.g. `"pt-BR"`, `"es_419"`) to one of
 * the offerwall's supported locales, falling back to `en`.
 */
export function mapLocale(input?: string | null): QuestLocale {
  if (!input) return "en";
  const lang = input.toLowerCase().split(/[-_]/)[0];
  return (SUPPORTED_LOCALES as readonly string[]).includes(lang)
    ? (lang as QuestLocale)
    : "en";
}

export interface BuildLaunchUrlParams {
  /** Hosted offerwall base URL, no trailing slash required. */
  baseUrl: string;
  appId: string;
  userId: string;
  /** Already resolved to a supported locale. */
  locale: string;
  /** Present in secure mode only. */
  token?: LaunchToken;
}

function param(key: string, value: string): string {
  return `${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
}

/**
 * Pure builder for the offerwall launch URL:
 * `{base}/?app_id=..&user_id=..[&ts=&nonce=&sig=]&locale=..`
 *
 * We build the query string manually with `encodeURIComponent` rather than
 * `URLSearchParams`, whose React Native polyfill is incomplete.
 */
export function buildLaunchUrl(params: BuildLaunchUrlParams): string {
  const { baseUrl, appId, userId, locale, token } = params;

  const parts = [param("app_id", appId), param("user_id", userId)];

  if (token) {
    parts.push(param("ts", String(token.ts)));
    parts.push(param("nonce", token.nonce));
    parts.push(param("sig", token.sig));
  }

  // Always sent, so the server never has to guess the render locale.
  parts.push(param("locale", locale));

  const base = baseUrl.replace(/\/+$/, "");
  return `${base}/?${parts.join("&")}`;
}
