// lib/core/backend/app_config.dart

class AppConfig {
  AppConfig._();

  /// Appwrite Endpoint URL (e.g. https://nyc.cloud.appwrite.io/v1)
  static const String appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://nyc.cloud.appwrite.io/v1',
  );

  /// Appwrite Project ID (public client ID)
  static const String appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6a74b9120005e1737ec6',
  );

  /// Appwrite Core Function ID
  static const String appwriteFunctionId = String.fromEnvironment(
    'APPWRITE_FUNCTION_ID',
    defaultValue: 'ritmo-core',
  );

  static String get cleanEndpoint {
    final ep = appwriteEndpoint.trim();
    if (ep == 'https://cloud.appwrite.io/v1') {
      return 'https://nyc.cloud.appwrite.io/v1';
    }
    return ep;
  }

  static bool get isAppwriteConfigured =>
      appwriteProjectId.isNotEmpty && cleanEndpoint.isNotEmpty;
}
