import Constants from "expo-constants";

import type { Environment, TheQuestConfig } from "./types";

const BASE_URLS: Record<Environment, string> = {
  production: "https://quest.humanlabs.world",
  staging: "https://quest.seriesc.dev",
};

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

/** Resolves the hosted offerwall base URL for the given environment. */
export function baseUrlFor(environment?: Environment): string {
  return BASE_URLS[environment ?? "production"] ?? BASE_URLS.production;
}
