import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

class BlockedUserModel {
  const BlockedUserModel({
    required this.id,
    required this.nama,
  });

  final int id;
  final String nama;

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      id: json['id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
    );
  }
}

class ModerationRepository {
  ModerationRepository(this._client);

  final ApiClient _client;

  ApiClient get client => _client;

  /// Mengirim laporan untuk listing, event, atau user.
  Future<int> report({
    required String targetType,
    required int targetId,
    required String alasan,
    String? keterangan,
  }) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/reports',
        data: {
          'target_type': targetType,
          'target_id': targetId,
          'alasan': alasan,
          if (keterangan != null && keterangan.trim().isNotEmpty)
            'keterangan': keterangan.trim(),
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      return data?['id'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Memblokir pengguna lain berdasarkan ID.
  Future<bool> blockUser(int userId) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/users/$userId/block',
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      return data?['blocked'] as bool? ?? true;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Membuka blokir pengguna lain berdasarkan ID.
  Future<bool> unblockUser(int userId) async {
    try {
      final res = await _client.dio.delete<Map<String, dynamic>>(
        '/users/$userId/block',
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      return data?['blocked'] as bool? ?? false;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengambil daftar pengguna yang diblokir oleh pengguna aktif.
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    try {
      final res = await _client.dio.get<Map<String, dynamic>>('/me/blocks');
      final list = res.data?['data'] as List<dynamic>? ?? [];
      return list
          .map((item) => BlockedUserModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
