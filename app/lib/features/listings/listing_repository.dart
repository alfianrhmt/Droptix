import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'listing_models.dart';

/// Klien API untuk membuat, membaca, dan mengelola listing tiket.
class ListingRepository {
  ListingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ListingItem>> getMyListings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/me/listings',
        queryParameters: {
          'status': ?status,
          'page': page,
          'limit': limit,
        },
      );
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) =>
              ListingItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ListingItem> createListing(Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.dio.post<Map<String, dynamic>>(
        '/listings',
        data: payload,
      );
      return ListingItem.fromJson(
        Map<String, dynamic>.from(res.data!['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ListingItem> updateListing(
      int id, Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.dio.put<Map<String, dynamic>>(
        '/listings/$id',
        data: payload,
      );
      return ListingItem.fromJson(
        Map<String, dynamic>.from(res.data!['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ListingItem> updateStock(int id, int jumlahTerjual) async {
    try {
      final res = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/listings/$id/stock',
        data: {'jumlah_terjual': jumlahTerjual},
      );
      return ListingItem.fromJson(
        Map<String, dynamic>.from(res.data!['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DateTime> confirmListing(int id) async {
    try {
      final res = await _apiClient.dio.post<Map<String, dynamic>>(
        '/listings/$id/confirm',
      );
      final data = Map<String, dynamic>.from(res.data!['data'] as Map);
      return DateTime.parse(data['confirmed_at'] as String);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteListing(int id) async {
    try {
      await _apiClient.dio.delete<void>('/listings/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ListingItem> getListingDetail(int id,
      {double? lat, double? lng}) async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/listings/$id',
        queryParameters: {
          'lat': ?lat,
          'lng': ?lng,
        },
      );
      return ListingItem.fromJson(
        Map<String, dynamic>.from(res.data!['data'] as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<String> uploadTicketPhoto(
    Uint8List bytes, {
    String filename = 'ticket.png',
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _apiClient.dio.post<Map<String, dynamic>>(
        '/uploads',
        data: formData,
      );
      final data = Map<String, dynamic>.from(res.data!['data'] as Map);
      return data['url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

