import type { Options } from '@wdio/types';

export const config: Options.Testrunner = {
  runner: 'local',
  autoCompileOpts: {
    autoCompile: true,
    tsNodeOpts: { transpileOnly: true },
  },
  specs: ['./test/specs/*.spec.ts'],
  maxInstances: 1,
  hostname: '127.0.0.1',
  port: 4723,
  path: '/',
  capabilities: [{
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    'appium:deviceName': 'Redmi Note 7',
    'appium:udid': process.env.DEVICE_UDID || '100.116.179.88:5555',
    'appium:appPackage': 'com.studex.driver_app',
    'appium:appActivity': '.MainActivity',
    'appium:noReset': true,
    'appium:dontStopAppOnReset': true,
    'appium:skipDeviceInitialization': true,
    'appium:skipServerInstallation': true,
    'appium:newCommandTimeout': 300,
    'appium:settings[waitForIdleTimeout]': 0,
    'appium:settings[waitForSelectorTimeout]': 0,
    'appium:settings[scrollAcknowledgmentTimeout]': 200,
  }],
  services: [],
  logLevel: 'warn',
  bail: 0,
  waitforTimeout: 8000,
  connectionRetryTimeout: 60000,
  connectionRetryCount: 2,
  framework: 'mocha',
  mochaOpts: { ui: 'bdd', timeout: 60000 },
  reporters: ['spec'],
  afterTest: async (_test, _context, { error }) => {
    if (error) { try { await browser.takeScreenshot(); } catch {} }
  },
};
