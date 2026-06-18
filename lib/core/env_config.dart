class EnvConfig {
  static const String serverUrl = String.fromEnvironment('SERVER_URL',
      defaultValue: 'http://100.94.188.107:9080');
  static const String realtimeUrl = String.fromEnvironment('REALTIME_URL',
      defaultValue: 'http://100.94.188.107:9081');
  static const String wsUrl = String.fromEnvironment('WS_URL',
      defaultValue: 'ws://100.94.188.107:9081');
}
