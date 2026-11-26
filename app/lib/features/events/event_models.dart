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
      slug == 'konser-festival' || slug == 'olahraga';

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
    this.availableTicketsCount,
  });

  final int id;
  final String nama;
  final String? posterUrl;
  final EventCategory category;
  final VenueItem? venue;
  final DateTime? tanggal;
  final List<String> tanggalOpsi;
  final int? availableTicketsCount;

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
      availableTicketsCount:
          (json['available_tickets_count'] as num?)?.toInt(),
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

/// Model ringkasan poster untuk banner hype triptych.
class BannerPosterSummary {
  const BannerPosterSummary({
    required this.id,
    required this.nama,
    this.posterUrl,
  });

  final int id;
  final String nama;
  final String? posterUrl;

  factory BannerPosterSummary.fromJson(Map<String, dynamic> json) {
    return BannerPosterSummary(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '',
      posterUrl: json['poster_url'] as String?,
    );
  }
}

/// Model data banner promosi & etalase editorial home.
class AppBanner {
  const AppBanner({
    required this.id,
    required this.type,
    this.badge,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    required this.targetType,
    this.targetPayload,
    this.imageUrl,
    this.gradientColors = const [],
    this.posters = const [],
  });

  final int id;
  final String type; // 'standard' | 'hype_triptych'
  final String? badge;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final String targetType; // 'category' | 'search' | 'sell' | 'filter'
  final String? targetPayload;
  final String? imageUrl;
  final List<String> gradientColors;
  final List<BannerPosterSummary> posters;

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    final rawColors = json['gradient_colors'] as List<dynamic>? ?? const [];
    final rawPosters = json['posters'] as List<dynamic>? ?? const [];

    return AppBanner(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? 'standard',
      badge: json['badge'] as String?,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      ctaLabel: json['cta_label'] as String?,
      targetType: json['target_type'] as String? ?? 'search',
      targetPayload: json['target_payload'] as String?,
      imageUrl: json['image_url'] as String?,
      gradientColors: rawColors.map((c) => c.toString()).toList(),
      posters: rawPosters
          .map((p) =>
              BannerPosterSummary.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  BannerItem toBannerItem() {
    return BannerItem(
      imageUrl: imageUrl ?? '',
      eventName: title,
      keyword: targetPayload ?? title,
      appBanner: this,
    );
  }
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

/// Statistik ketersediaan tiket pada EventDetailModel.
class EventStatsModel {
  const EventStatsModel({
    required this.availableTicketsCount,
    this.minPrice,
    this.maxPrice,
    required this.sellersCount,
  });

  final int availableTicketsCount;
  final int? minPrice;
  final int? maxPrice;
  final int sellersCount;

  factory EventStatsModel.fromJson(Map<String, dynamic> json) {
    return EventStatsModel(
      availableTicketsCount:
          (json['available_tickets_count'] as num?)?.toInt() ?? 0,
      minPrice: (json['min_price'] as num?)?.toInt(),
      maxPrice: (json['max_price'] as num?)?.toInt(),
      sellersCount: (json['sellers_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model data lengkap Halaman Event (Event Hub).
class EventDetailModel {
  const EventDetailModel({
    required this.event,
    required this.stats,
    required this.isAlertActive,
    required this.listings,
  });

  final EventItem event;
  final EventStatsModel stats;
  final bool isAlertActive;
  final List<ListingItem> listings;

  factory EventDetailModel.fromJson(Map<String, dynamic> json) {
    final eventMap = Map<String, dynamic>.from(json['event'] as Map);
    final statsMap =
        Map<String, dynamic>.from(json['stats'] as Map? ?? const {});
    final rawListings = json['listings'] as List<dynamic>? ?? const [];

    return EventDetailModel(
      event: EventItem.fromJson(eventMap),
      stats: EventStatsModel.fromJson(statsMap),
      isAlertActive: json['is_alert_active'] as bool? ?? false,
      listings: rawListings
          .map((item) =>
              ListingItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  EventDetailModel copyWith({
    EventItem? event,
    EventStatsModel? stats,
    bool? isAlertActive,
    List<ListingItem>? listings,
  }) {
    return EventDetailModel(
      event: event ?? this.event,
      stats: stats ?? this.stats,
      isAlertActive: isAlertActive ?? this.isAlertActive,
      listings: listings ?? this.listings,
    );
  }
}

/// Model data event populer untuk section Acara Pilihan di Home.
class PopularEventItem {
  const PopularEventItem({
    required this.event,
    required this.availableTicketsCount,
    this.minPrice,
    required this.sellersCount,
  });

  final EventItem event;
  final int availableTicketsCount;
  final int? minPrice;
  final int sellersCount;

  factory PopularEventItem.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : const <String, dynamic>{};
    return PopularEventItem(
      event: EventItem.fromJson(json),
      availableTicketsCount:
          (stats['available_tickets_count'] as num?)?.toInt() ?? 0,
      minPrice: (stats['min_price'] as num?)?.toInt(),
      sellersCount: (stats['sellers_count'] as num?)?.toInt() ?? 0,
    );
  }
}


