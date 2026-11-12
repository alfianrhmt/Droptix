/// Konfigurasi URL dasar API Droptix.
/// Dapat diubah saat build dengan `--dart-define=API_BASE_URL=https://...`.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// Host dasar tanpa `/api/v1` untuk merender path `/uploads/...`.
  static String get hostUrl {
    return baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
  }
}

