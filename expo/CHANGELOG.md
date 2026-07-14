# Changelog

## [0.2.0](https://github.com/humanlabs-kr/the-quest-sdk/compare/expo-v0.1.0...expo-v0.2.0) (2026-07-14)


### Features

* **expo:** rename package to @humanlabs-kr/quest-offerwall-expo ([0927cdc](https://github.com/humanlabs-kr/the-quest-sdk/commit/0927cdc6789b552c657a950c8c8bcfa6e4e59fef))
* initial The Quest offerwall SDK for iOS, Android, and Expo ([8cc9911](https://github.com/humanlabs-kr/the-quest-sdk/commit/8cc99114cd52e9e6ae6029271b7ff38dc6d8dcb3))

## Changelog

## Unreleased

- Initial release of `@humanlabs-kr/quest-offerwall-expo`.
- `TheQuest.show()` + `<TheQuestProvider>` to present the hosted offerwall in a
  full-screen `react-native-webview`.
- Standard (unsigned) and secure (`launchProvider`) launch modes.
- Native ↔ web bridge (`openUrl` / `close` / `ready`) per `docs/BRIDGE.md`.
- Build-time config via `extra.theQuest` or the optional Expo config plugin.
