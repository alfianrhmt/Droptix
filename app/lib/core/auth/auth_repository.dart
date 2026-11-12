import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import 'user_model.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});
  final String token;
  final UserModel user;
}

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> register({
    required String nama,
    required String email,
    required String password,
    required bool setujuSyarat,
    String? noWa,
    String? kota,
  }) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'nama': nama,
          'email': email,
          'password': password,
          'setuju_syarat': setujuSyarat,
          if (noWa != null && noWa.isNotEmpty) 'no_wa': noWa,
          if (kota != null && kota.isNotEmpty) 'kota': kota,
        },
      );
      final data = res.data!['data'] as Map<String, dynamic>;
      return AuthResult(
        token: data['token'] as String,
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final data = res.data!['data'] as Map<String, dynamic>;
      return AuthResult(
        token: data['token'] as String,
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel> getMe() async {
    try {
      final res = await _client.dio.get<Map<String, dynamic>>('/me');
      final data = res.data!['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel> updateMe({
    String? nama,
    String? noWa,
    String? kota,
  }) async {
    try {
      final res = await _client.dio.put<Map<String, dynamic>>(
        '/me',
        data: {
          'nama': ?nama,
          'no_wa': ?noWa,
          'kota': ?kota,
        },
      );
      final data = res.data!['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updatePassword({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    try {
      await _client.dio.put<Map<String, dynamic>>(
        '/me/password',
        data: {
          'password_lama': passwordLama,
          'password_baru': passwordBaru,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

