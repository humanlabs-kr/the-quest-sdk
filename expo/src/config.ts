import Constants from "expo-constants";

import type { TheQuestConfig } from "./types";

/** The default (production) offerwall base URL, used when `baseUrl` is unset. */
export const DEFAULT_BASE_URL = "https://quest.humanlabs.world";

/**
 * Reads `extra.theQuest` from the Expo app config. Returns `undefined` when it
 * has not been configured (the caller reports a clear error in that case).
 */
export function readConfig(): TheQuestConfig | undefined {
  const extra =
    Constants.expoConfig?.extra ??
    // Fallbacks for older manifests / bare workflows.
    (Constants as unknown as { manifest2?: { extra?: Record<string, unknown> } })
      .manifest2?.extra ??
    (Constants as unknown as { manifest?: { extra?: Record<string, unknown> } })
      .manifest?.extra;

  const theQuest = (extra as { theQuest?: TheQuestConfig } | undefined)?.theQuest;
  return theQuest;
}

/**
 * Resolves the offerwall base URL for a config: an explicit `baseUrl` wins,
 * otherwise the production URL.
 */
export function resolveBaseUrl(config: TheQuestConfig | undefined): string {
  const explicit = config?.baseUrl?.trim();
  return explicit || DEFAULT_BASE_URL;
}
