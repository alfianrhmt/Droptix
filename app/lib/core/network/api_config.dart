import 'package:flutter/foundation.dart';

/// Konfigurasi URL dasar API Droptix.
/// Dapat diubah saat build dengan `--dart-define=API_BASE_URL=https://...`.
abstract final class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        final port = Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443
            ? ':${Uri.base.port}'
            : '';
        final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
        return '$scheme://$host$port/api/v1';
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  /// Host dasar tanpa `/api/v1` untuk merender path `/uploads/...`.
  static String get hostUrl {
    return baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
  }
}
