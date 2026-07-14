# Changelog

## Unreleased

- Initial release of `@humanlabs-kr/quest-offerwall-expo`.
- `TheQuest.show()` + `<TheQuestProvider>` to present the hosted offerwall in a
  full-screen `react-native-webview`.
- Standard (unsigned) and secure (`launchProvider`) launch modes.
- Native ↔ web bridge (`openUrl` / `close` / `ready`) per `docs/BRIDGE.md`.
- Build-time config via `extra.theQuest` or the optional Expo config plugin.
