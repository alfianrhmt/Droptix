import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'event_models.dart';

/// Klien API untuk kategori, venue, event, dan unggahan poster.
class EventRepository {
  EventRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<EventCategory>> getCategories() async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>('/categories');
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((e) => EventCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<VenueItem>> getVenues({
    String? q,
    String? kota,
    String? userKota,
    double? lat,
    double? lng,
  }) async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/venues',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (kota != null && kota.trim().isNotEmpty) 'kota': kota.trim(),
          if (userKota != null && userKota.trim().isNotEmpty) 'user_kota': userKota.trim(),
          'lat': ?lat,
          'lng': ?lng,
        },
      );
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((e) => VenueItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<VenueItem> createVenue({
    required String nama,
    required String kota,
    String? alamat,
  }) async {
    try {
      final res = await _apiClient.dio.post<Map<String, dynamic>>(
        '/venues',
        data: {
          'nama': nama.trim(),
          'kota': kota.trim(),
          if (alamat != null && alamat.trim().isNotEmpty)
            'alamat': alamat.trim(),
        },
      );
      final data = Map<String, dynamic>.from(res.data!['data'] as Map);
      return VenueItem.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<EventItem>> searchEvents({
    String? q,
    String? categorySlug,
  }) async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (categorySlug != null && categorySlug.isNotEmpty)
            'category': categorySlug,
        },
      );
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((e) => EventItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<EventItem> createEvent({
    required int categoryId,
    required String nama,
    String? posterUrl,
    int? venueId,
    DateTime? tanggal,
    List<String>? tanggalOpsi,
    bool force = false,
  }) async {
    try {
      final res = await _apiClient.dio.post<Map<String, dynamic>>(
        '/events',
        data: {
          'category_id': categoryId,
          'nama': nama.trim(),
          'poster_url': ?posterUrl,
          'venue_id': ?venueId,
          if (tanggal != null) 'tanggal': tanggal.toUtc().toIso8601String(),
          if (tanggalOpsi != null && tanggalOpsi.isNotEmpty)
            'tanggal_opsi': tanggalOpsi,
          if (force) 'force': true,
        },
      );
      final data = Map<String, dynamic>.from(res.data!['data'] as Map);
      return EventItem.fromJson(data);
    } on DioException catch (e) {
      final errorBody = e.response?.data;
      if (e.response?.statusCode == 409 &&
          errorBody is Map<String, dynamic> &&
          errorBody['error'] is Map<String, dynamic>) {
        final err = errorBody['error'] as Map<String, dynamic>;
        if (err['code'] == 'SIMILAR_EVENT_EXISTS') {
          final rawList = err['similar'] as List<dynamic>? ?? const [];
          final similar = rawList
              .map((item) => SimilarEventItem.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
          throw SimilarEventException(similar);
        }
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<String> uploadPoster(Uint8List bytes,
      {String filename = 'poster.png'}) async {
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

  Future<List<TrendingBanner>> getTrending({double? lat, double? lng}) async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/events/trending',
        queryParameters: {
          'lat': ?lat,
          'lng': ?lng,
        },
      );
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) => TrendingBanner.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<AppBanner>> getBanners() async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>('/banners');
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) =>
              AppBanner.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<PopularEventItem>> getPopularEvents() async {
    try {
      final res =
          await _apiClient.dio.get<Map<String, dynamic>>('/events/popular');
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) =>
              PopularEventItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<EventDetailModel> getEventDetail(
    int id, {
    String? sort,
    double? lat,
    double? lng,
    int? venueId,
    String? tanggal,
  }) async {
    try {
      final res = await _apiClient.dio.get<Map<String, dynamic>>(
        '/events/$id',
        queryParameters: {
          if (sort != null && sort.isNotEmpty) 'sort': sort,
          'lat': ?lat,
          'lng': ?lng,
          'venue_id': ?venueId,
          if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
        },
      );
      final data = Map<String, dynamic>.from(res.data!['data'] as Map);
      return EventDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<bool> toggleEventAlert(int eventId) async {
    try {
      final res = await _apiClient.dio.post<Map<String, dynamic>>(
        '/events/$eventId/alert',
      );
      final data = Map<String, dynamic>.from(res.data!['data'] as Map);
      return data['is_active'] as bool? ?? false;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
