import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  Modal,
  Platform,
  Pressable,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from "react-native";
import * as Linking from "expo-linking";
import * as Localization from "expo-localization";
import { WebView } from "react-native-webview";

import { BRIDGE_SHIM, parseBridgeMessage } from "./bridge";
import { baseUrlFor, readConfig } from "./config";
import { buildLaunchUrl, mapLocale } from "./launchUrl";
import { _registerHost, type ShowRequest } from "./TheQuest";
import type { LaunchToken } from "./types";
import { SDK_VERSION } from "./version";

const APPLICATION_NAME_FOR_UA = `TheQuestSDK/${SDK_VERSION} (expo)`;

function getDeviceLocale(): string | undefined {
  try {
    const locales = Localization.getLocales();
    if (locales.length > 0) {
      return locales[0].languageTag ?? locales[0].languageCode ?? undefined;
    }
  } catch {
    // expo-localization may be absent (optional peer) — fall through.
  }
  return undefined;
}

function originOf(url: string): string | null {
  const match = /^(https?:\/\/[^/]+)/i.exec(url);
  return match ? match[1].toLowerCase() : null;
}

/**
 * Mount once at your app root. Hosts the imperative full-screen offerwall modal
 * that {@link TheQuest.show} drives.
 */
export function TheQuestProvider({
  children,
}: {
  children: React.ReactNode;
}): React.JSX.Element {
  const [visible, setVisible] = useState(false);
  const [uri, setUri] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const requestRef = useRef<ShowRequest | null>(null);
  const baseUrlRef = useRef<string>("");
  const webViewRef = useRef<WebView>(null);

  const finish = useCallback(() => {
    const request = requestRef.current;
    requestRef.current = null;
    setVisible(false);
    setUri(null);
    setReady(false);
    setError(null);
    if (request) {
      try {
        request.options.onClose?.();
      } catch (err) {
        console.warn("[TheQuest] onClose callback threw:", err);
      }
      request.resolve();
    }
  }, []);

  const prepare = useCallback(async (request: ShowRequest) => {
    try {
      let token: LaunchToken | undefined;
      if (request.options.launchProvider) {
        token = await request.options.launchProvider(request.options.userId);
        if (!token || !token.sig || !token.nonce || token.ts === undefined || token.ts === null) {
          throw new Error(
            "[TheQuest] launchProvider must resolve to a LaunchToken with { ts, nonce, sig }.",
          );
        }
      }

      // Ignore results from a launch that was closed while we awaited.
      if (requestRef.current !== request) return;

      const locale = mapLocale(
        request.options.locale ?? token?.locale ?? getDeviceLocale(),
      );
      const launchUrl = buildLaunchUrl({
        baseUrl: baseUrlRef.current,
        appId: readConfig()?.appId ?? "",
        userId: request.options.userId,
        locale,
        token,
      });
      setUri(launchUrl);
    } catch (err) {
      console.error("[TheQuest] Failed to prepare the launch:", err);
      if (requestRef.current === request) {
        setError("Couldn't start the offerwall. Please try again.");
      }
    }
  }, []);

  const startLoad = useCallback(
    (request: ShowRequest) => {
      const config = readConfig();
      if (!config?.appId) {
        const message =
          "[TheQuest] Missing appId. Set `extra.theQuest.appId` in app.json/app.config, " +
          "or use the @thequest/offerwall-expo config plugin.";
        console.error(message);
        request.reject(new Error(message));
        return;
      }

      if (requestRef.current) {
        const message = "[TheQuest] The offerwall is already open.";
        console.error(message);
        request.reject(new Error(message));
        return;
      }

      requestRef.current = request;
      baseUrlRef.current = baseUrlFor(config.environment);
      setError(null);
      setReady(false);
      setUri(null);
      setVisible(true);
      void prepare(request);
    },
    [prepare],
  );

  useEffect(() => {
    _registerHost((request) => startLoad(request));
    return () => _registerHost(null);
  }, [startLoad]);

  const retry = useCallback(() => {
    const request = requestRef.current;
    if (!request) return;
    setError(null);
    setReady(false);
    if (uri) {
      webViewRef.current?.reload();
    } else {
      void prepare(request);
    }
  }, [prepare, uri]);

  const handleMessage = useCallback(
    (data: unknown) => {
      const message = parseBridgeMessage(data);
      if (!message) return;
      switch (message.type) {
        case "openUrl": {
          const url = (message as { url?: unknown }).url;
          if (typeof url === "string" && url.length > 0) {
            // Open externally only — never navigate the offerwall WebView.
            Linking.openURL(url).catch((err) =>
              console.warn("[TheQuest] openUrl failed:", err),
            );
          }
          break;
        }
        case "close":
          finish();
          break;
        case "ready":
          setReady(true);
          break;
        default:
          break;
      }
    },
    [finish],
  );

  // Keep the WebView on our own origin; route everything else to the OS.
  const handleShouldStart = useCallback((url: string): boolean => {
    if (url === "about:blank" || url.startsWith("about:") || url.startsWith("data:")) {
      return true;
    }
    const base = baseUrlRef.current;
    if (base && (url === base || url.startsWith(`${base}/`))) return true;

    const target = originOf(url);
    if (target && target === originOf(base)) return true;

    // External http(s) link or custom scheme deep link → hand off to the OS.
    Linking.openURL(url).catch((err) =>
      console.warn("[TheQuest] external navigation failed:", err),
    );
    return false;
  }, []);

  const showSpinner = visible && !error && !ready;

  return (
    <>
      {children}
      <TheQuestModal
        visible={visible}
        uri={uri}
        error={error}
        showSpinner={showSpinner}
        webViewRef={webViewRef}
        onClose={finish}
        onRetry={retry}
        onMessage={handleMessage}
        onReady={() => setReady(true)}
        onError={() => setError("The offerwall failed to load.")}
        onShouldStart={handleShouldStart}
      />
    </>
  );
}

interface ModalProps {
  visible: boolean;
  uri: string | null;
  error: string | null;
  showSpinner: boolean;
  webViewRef: React.RefObject<WebView>;
  onClose: () => void;
  onRetry: () => void;
  onMessage: (data: unknown) => void;
  onReady: () => void;
  onError: () => void;
  onShouldStart: (url: string) => boolean;
}

// Split out so the WebView (and its heavy native view) only mounts while visible.
function TheQuestModal(props: ModalProps): React.JSX.Element {
  const {
    visible,
    uri,
    error,
    showSpinner,
    webViewRef,
    onClose,
    onRetry,
    onMessage,
    onReady,
    onError,
    onShouldStart,
  } = props;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      onRequestClose={onClose}
      presentationStyle="fullScreen"
      statusBarTranslucent
    >
      <SafeAreaView style={styles.container}>
        <View style={styles.androidStatusBarInset} />
        <View style={styles.header}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Close"
            hitSlop={12}
            onPress={onClose}
            style={styles.closeButton}
          >
            <Text style={styles.closeIcon}>✕</Text>
          </Pressable>
        </View>

        <View style={styles.body}>
          {error ? (
            <View style={styles.centered}>
              <Text style={styles.errorText}>{error}</Text>
              <Pressable
                accessibilityRole="button"
                onPress={onRetry}
                style={styles.retryButton}
              >
                <Text style={styles.retryText}>Retry</Text>
              </Pressable>
            </View>
          ) : uri ? (
            <WebView
              ref={webViewRef}
              source={{ uri }}
              style={styles.webview}
              injectedJavaScriptBeforeContentLoaded={BRIDGE_SHIM}
              onMessage={(event) => onMessage(event.nativeEvent.data)}
              applicationNameForUserAgent={APPLICATION_NAME_FOR_UA}
              sharedCookiesEnabled
              thirdPartyCookiesEnabled
              domStorageEnabled
              originWhitelist={["https://*"]}
              onShouldStartLoadWithRequest={(request) => onShouldStart(request.url)}
              startInLoadingState
              renderLoading={() => <View />}
              onLoadEnd={onReady}
              onError={onError}
              onHttpError={(event) => {
                const { statusCode, url } = event.nativeEvent;
                if (statusCode >= 400 && uri && originOf(url) === originOf(uri)) {
                  onError();
                }
              }}
            />
          ) : null}

          {showSpinner ? (
            <View style={[StyleSheet.absoluteFill, styles.centered]} pointerEvents="none">
              <ActivityIndicator size="large" />
            </View>
          ) : null}
        </View>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
  androidStatusBarInset: {
    height: Platform.OS === "android" ? StatusBar.currentHeight ?? 0 : 0,
  },
  header: {
    height: 52,
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#E5E7EB",
  },
  closeButton: {
    width: 40,
    height: 40,
    alignItems: "center",
    justifyContent: "center",
  },
  closeIcon: {
    fontSize: 22,
    lineHeight: 24,
    color: "#111827",
  },
  body: {
    flex: 1,
  },
  webview: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
  centered: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
  },
  errorText: {
    fontSize: 15,
    color: "#374151",
    textAlign: "center",
    marginBottom: 16,
  },
  retryButton: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: "#111827",
  },
  retryText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "600",
  },
});
