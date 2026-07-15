// Optional Expo config plugin for @humanlabs-kr/quest-offerwall-expo.
//
// Lets integrators configure the SDK from their app config instead of writing
// `extra.theQuest` by hand:
//
//   // app.json
//   { "expo": { "plugins": [
//       ["@humanlabs-kr/quest-offerwall-expo", { "appId": "abc1234567" }]
//   ] } }
//
// Everything the plugin does is also achievable by setting `extra.theQuest`
// directly — the plugin is purely a convenience.

const pkg = require("./package.json");

/**
 * @param {import('@expo/config-types').ExpoConfig} config
 * @param {{ appId?: string, baseUrl?: string }} [props]
 */
const withTheQuest = (config, props = {}) => {
  const { appId, baseUrl } = props || {};

  config.extra = config.extra || {};
  config.extra.theQuest = {
    ...(config.extra.theQuest || {}),
    ...(appId !== undefined ? { appId } : {}),
    ...(baseUrl !== undefined ? { baseUrl } : {}),
  };

  return config;
};

// Use createRunOncePlugin when @expo/config-plugins is available (it ships with
// every Expo project) so the plugin is idempotent; fall back to the plain
// function otherwise to keep this dependency-light.
let plugin = withTheQuest;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { createRunOncePlugin } = require("@expo/config-plugins");
  if (typeof createRunOncePlugin === "function") {
    plugin = createRunOncePlugin(withTheQuest, pkg.name, pkg.version);
  }
} catch {
  // @expo/config-plugins not installed — export the plain mutator.
}

module.exports = plugin;
