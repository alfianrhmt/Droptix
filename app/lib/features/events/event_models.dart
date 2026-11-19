import '../../core/widgets/banner_carousel.dart';
import '../listings/listing_models.dart';

/// Model data kategori event.
class EventCategory {
  const EventCategory({
    required this.id,
    required this.slug,
    required this.nama,
    required this.ikon,
    required this.urutan,
  });

  final int id;
  final String slug;
  final String nama;
  final String ikon;
  final int urutan;

  bool get requiresVenue =>
      slug == 'konser-festival' || slug == 'olahraga' || slug == 'wisata';

  bool get requiresDate =>
      slug == 'konser-festival' || slug == 'olahraga';

  bool get requiresTime =>
      slug == 'konser-festival' || slug == 'olahraga' || slug == 'bioskop';

  bool get requiresVenueAndDate => requiresVenue && requiresDate;

  factory EventCategory.fromJson(Map<String, dynamic> json) {
    return EventCategory(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      nama: json['nama'] as String,
      ikon: (json['ikon'] as String?) ?? 'event',
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model data venue acara.
class VenueItem {
  const VenueItem({
    required this.id,
    required this.nama,
    required this.kota,
    this.alamat,
    this.lat,
    this.lng,
  });

  final int id;
  final String nama;
  final String kota;
  final String? alamat;
  final double? lat;
  final double? lng;

  factory VenueItem.fromJson(Map<String, dynamic> json) {
    return VenueItem(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      kota: json['kota'] as String,
      alamat: json['alamat'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

/// Model data event hasil pencarian atau pembuatan event baru.
class EventItem {
  const EventItem({
    required this.id,
    required this.nama,
    this.posterUrl,
    required this.category,
    this.venue,
    this.tanggal,
    this.tanggalOpsi = const [],
  });

  final int id;
  final String nama;
  final String? posterUrl;
  final EventCategory category;
  final VenueItem? venue;
  final DateTime? tanggal;
  final List<String> tanggalOpsi;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    final rawTanggalOpsi = json['tanggal_opsi'];
    List<String> parsedTanggalOpsi = const [];
    if (rawTanggalOpsi is List) {
      parsedTanggalOpsi = rawTanggalOpsi
          .map((e) => e.toString().split('T').first)
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final parsedTanggal = json['tanggal'] is String
        ? DateTime.tryParse(json['tanggal'] as String)
        : null;
    if (parsedTanggalOpsi.isEmpty && parsedTanggal != null) {
      parsedTanggalOpsi = [parsedTanggal.toIso8601String().split('T').first];
    }

    return EventItem(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      posterUrl: json['poster_url'] as String?,
      category: EventCategory.fromJson(
        Map<String, dynamic>.from(json['category'] as Map),
      ),
      venue: json['venue'] is Map
          ? VenueItem.fromJson(Map<String, dynamic>.from(json['venue'] as Map))
          : null,
      tanggal: parsedTanggal,
      tanggalOpsi: parsedTanggalOpsi,
    );
  }
}

/// Ringkasan event mirip yang dikembalikan saat `409 SIMILAR_EVENT_EXISTS`.
class SimilarEventItem {
  const SimilarEventItem({
    required this.id,
    required this.nama,
    this.posterUrl,
  });

  final int id;
  final String nama;
  final String? posterUrl;

  factory SimilarEventItem.fromJson(Map<String, dynamic> json) {
    return SimilarEventItem(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      posterUrl: json['poster_url'] as String?,
    );
  }
}

/// Exception khusus saat `POST /events` mendeteksi event dengan nama mirip.
class SimilarEventException implements Exception {
  const SimilarEventException(this.similar);

  final List<SimilarEventItem> similar;
}

/// Banner trending hasil GET /events/trending (BR-6).
class TrendingBanner {
  const TrendingBanner({
    required this.type,
    required this.categorySlug,
    this.event,
    this.listing,
  });

  final String type; // 'event' | 'nearest'
  final String categorySlug;
  final ListingEventSummary? event;
  final ListingItem? listing;

  factory TrendingBanner.fromJson(Map<String, dynamic> json) {
    return TrendingBanner(
      type: json['type'] as String? ?? 'event',
      categorySlug: json['category_slug'] as String? ?? '',
      event: json['event'] is Map
          ? ListingEventSummary.fromJson(
              Map<String, dynamic>.from(json['event'] as Map))
          : null,
      listing: json['listing'] is Map
          ? ListingItem.fromJson(
              Map<String, dynamic>.from(json['listing'] as Map))
          : null,
    );
  }

  BannerItem toBannerItem() {
    if (type == 'nearest' && listing != null) {
      return BannerItem(
        imageUrl: listing!.event.posterUrl ?? '',
        eventName: listing!.event.nama,
        keyword: listing!.event.nama,
      );
    }
    return BannerItem(
      imageUrl: event?.posterUrl ?? '',
      eventName: event?.nama ?? '',
      keyword: event?.nama,
    );
  }
}

