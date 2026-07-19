class EnvConfig {
  static const String serverUrl = String.fromEnvironment('SERVER_URL',
      defaultValue: 'https://ag-studex.izcy.tech');
  static const String realtimeUrl = String.fromEnvironment('REALTIME_URL',
      defaultValue: 'https://rg-studex.izcy.tech');
  static const String wsUrl = String.fromEnvironment('WS_URL',
      defaultValue: 'wss://rg-studex.izcy.tech/ws');
}
