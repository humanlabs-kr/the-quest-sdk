import type { ShowOptions } from "./types";

/**
 * Internal request handed from {@link TheQuest.show} to the mounted
 * `<TheQuestProvider>`. The promise settles when the offerwall closes (resolve)
 * or when the launch can't be started (reject).
 */
export interface ShowRequest {
  options: ShowOptions;
  resolve: () => void;
  reject: (error: Error) => void;
}

type Host = (request: ShowRequest) => void;

let host: Host | null = null;

/**
 * Registered by `<TheQuestProvider>` on mount. Internal — not part of the public
 * API surface (re-exports in index.ts intentionally omit it).
 */
export function _registerHost(next: Host | null): void {
  host = next;
}

export const TheQuest = {
  /**
   * Presents the offerwall full-screen. Resolves when it is dismissed.
   *
   * - Standard mode: `show({ userId })`.
   * - Secure mode: also pass `launchProvider` (see docs/SIGNING.md).
   *
   * Requires `<TheQuestProvider>` mounted once at your app root.
   */
  show(options: ShowOptions): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      if (!options || typeof options.userId !== "string" || options.userId.length === 0) {
        const error = new Error("[TheQuest] show() requires a non-empty `userId`.");
        console.error(error.message);
        reject(error);
        return;
      }

      if (!host) {
        const error = new Error(
          "[TheQuest] <TheQuestProvider> is not mounted. Wrap your app root with it before calling show().",
        );
        console.error(error.message);
        reject(error);
        return;
      }

      host({ options, resolve, reject });
    });
  },
};
