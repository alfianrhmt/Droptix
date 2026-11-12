import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import 'api_config.dart';
import 'api_error.dart';

/// Klien HTTP berbasis [Dio] dengan interceptor JWT dan penanganan error seragam.
class ApiClient {
  ApiClient({
    required this.tokenStorage,
    this.onUnauthorized,
    Dio? dio,
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await tokenStorage.readToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onError: (err, handler) async {
              final apiErr = ApiException.fromDio(err);
              final path = err.requestOptions.path;
              final isAuthRoute = path.contains('/auth/login') ||
                  path.contains('/auth/register');

              if (!isAuthRoute &&
                  (apiErr.code == 'UNAUTHORIZED' ||
                      apiErr.code == 'ACCOUNT_BANNED')) {
                await tokenStorage.clear();
                onUnauthorized?.call(apiErr.code);
              }
              handler.next(err);
            },
          ),
        );
  }

  final Dio dio;
  final TokenStorage tokenStorage;
  final void Function(String code)? onUnauthorized;
}

