# Changelog

## [1.0.1](https://github.com/humanlabs-kr/the-quest-sdk/compare/expo-v1.0.0...expo-v1.0.1) (2026-07-15)


### Bug Fixes

* **expo:** tolerate expo-image-picker MediaType API across the peer range ([14d1c8f](https://github.com/humanlabs-kr/the-quest-sdk/commit/14d1c8fc7698fd44fc094fbe1ab93816376b8ae6))

## [1.0.0](https://github.com/humanlabs-kr/the-quest-sdk/compare/expo-v0.2.0...expo-v1.0.0) (2026-07-15)


### ⚠ BREAKING CHANGES

* TheQuestEnvironment (iOS) / Environment (Android, Expo) is removed. Configure the offerwall base URL via `baseUrl` instead of an environment enum; it defaults to production.

### Features

* permission-free image picker, drop env enum, web-only header ([c4bf42b](https://github.com/humanlabs-kr/the-quest-sdk/commit/c4bf42bbeb3182a23b100e52ab5f09b5b05bbcd3))

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
