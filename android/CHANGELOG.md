# Changelog

## [1.0.0](https://github.com/humanlabs-kr/the-quest-sdk/compare/android-v0.2.0...android-v1.0.0) (2026-07-15)


### ⚠ BREAKING CHANGES

* TheQuestEnvironment (iOS) / Environment (Android, Expo) is removed. Configure the offerwall base URL via `baseUrl` instead of an environment enum; it defaults to production.

### Features

* permission-free image picker, drop env enum, web-only header ([c4bf42b](https://github.com/humanlabs-kr/the-quest-sdk/commit/c4bf42bbeb3182a23b100e52ab5f09b5b05bbcd3))

## [0.2.0](https://github.com/humanlabs-kr/the-quest-sdk/compare/android-v0.1.0...android-v0.2.0) (2026-07-14)


### Features

* initial The Quest offerwall SDK for iOS, Android, and Expo ([8cc9911](https://github.com/humanlabs-kr/the-quest-sdk/commit/8cc99114cd52e9e6ae6029271b7ff38dc6d8dcb3))

## Changelog

All notable changes to the Android SDK are documented here. This project adheres to
[Semantic Versioning](https://semver.org/) and is released via
[release-please](https://github.com/googleapis/release-please).

## Unreleased

- Initial Android SDK: `TheQuest.show()`, hosted offerwall WebView with a native header,
  standard and secure (signed) launch modes, and the `TheQuestNative` JS bridge.
