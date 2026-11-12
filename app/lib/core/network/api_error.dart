import 'package:dio/dio.dart';

/// Representasi error seragam dari API Droptix (`docs/API.md` bagian 1).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  /// Mengubah [DioException] atau error lain menjadi [ApiException].
  factory ApiException.fromDio(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;

    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final errObj = data['error'] as Map<String, dynamic>;
      final fields = <String, String>{};
      final details = errObj['details'];
      if (details is List) {
        for (final item in details) {
          if (item is Map<String, dynamic>) {
            final field = item['field']?.toString();
            final msg = item['message']?.toString();
            if (field != null && msg != null && !fields.containsKey(field)) {
              fields[field] = msg;
            }
          }
        }
      }
      return ApiException(
        code: errObj['code']?.toString() ?? 'UNKNOWN_ERROR',
        message: errObj['message']?.toString() ?? 'Terjadi kesalahan.',
        statusCode: status,
        fieldErrors: fields,
      );
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          code: 'TIMEOUT',
          message: 'Koneksi ke server melebihi batas waktu. Coba lagi.',
          statusCode: status,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          code: 'NETWORK_ERROR',
          message: 'Tidak dapat terhubung ke server. Periksa internetmu.',
          statusCode: status,
        );
      default:
        return ApiException(
          code: 'UNKNOWN_ERROR',
          message: 'Terjadi kesalahan. Coba lagi.',
          statusCode: status,
        );
    }
  }

  @override
  String toString() => 'ApiException($code: $message)';
}

