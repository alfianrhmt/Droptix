import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'listing_models.dart';

/// Klien API untuk membuat, membaca, dan mengelola listing tiket.
class ListingRepository {
  ListingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedListings> getListings({
    String? q,
    String? category,
    String? jenis,
    String? tipe,
    String? kota,
    double? lat,
    double? lng,
    int? maxKm,
    int? minHarga,
    int? maxHarga,
    String? tanggal,
    int? dalamJam,
    bool? tersedia,
    String? sort,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (jenis != null && jenis.trim().isNotEmpty) 'jenis': jenis.trim(),
        if (tipe != null && tipe.trim().isNotEmpty) 'tipe': tipe.trim(),
        if (kota != null && kota.trim().isNotEmpty) 'kota': kota.trim(),
        'lat': ?lat,
        'lng': ?lng,
        'max_km': ?maxKm,
        'min_harga': ?minHarga,
        'max_harga': ?maxHarga,
        if (tanggal != null && tanggal.trim().isNotEmpty)
          'tanggal': tanggal.trim(),
        'dalam_jam': ?dalamJam,
        'tersedia': ?tersedia,
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort.trim(),
        'page': page,
        'limit': limit,
      };

      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/listings',
        queryParameters: queryParams,
      );
      return PaginatedListings.fromJson(
        Map<String, dynamic>.from(res.data ?? const {}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

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

