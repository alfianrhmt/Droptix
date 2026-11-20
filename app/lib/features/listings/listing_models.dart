import '../../core/widgets/badges.dart';
import '../../core/widgets/listing_widgets.dart';
import '../events/event_models.dart';

/// Hasil pagination listing tiket.
class PaginatedListings {
  const PaginatedListings({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<ListingItem> items;
  final int total;
  final int page;
  final int limit;

  factory PaginatedListings.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? const [];
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return PaginatedListings(
      items: list
          .map((item) =>
              ListingItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      total: (meta['total'] as num?)?.toInt() ?? list.length,
      page: (meta['page'] as num?)?.toInt() ?? 1,
      limit: (meta['limit'] as num?)?.toInt() ?? list.length,
    );
  }
}

/// Foto bukti tiket pada ListingDetail.
class ListingPhotoItem {
  const ListingPhotoItem({required this.id, required this.url});

  final int id;
  final String url;

  factory ListingPhotoItem.fromJson(Map<String, dynamic> json) {
    return ListingPhotoItem(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
    );
  }
}

/// Ringkasan penjual pada ListingDetail (tanpa no_wa atau email).
class ListingSellerInfo {
  const ListingSellerInfo({
    required this.id,
    required this.nama,
    this.username,
    required this.bergabung,
  });

  final int id;
  final String nama;
  final String? username;
  final DateTime? bergabung;

  factory ListingSellerInfo.fromJson(Map<String, dynamic> json) {
    return ListingSellerInfo(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      username: json['username'] as String?,
      bergabung: json['bergabung'] is String
          ? DateTime.tryParse(json['bergabung'] as String)
          : null,
    );
  }
}

/// Ringkasan event di dalam ListingCard / ListingDetail.
class ListingEventSummary {
  const ListingEventSummary({
    required this.id,
    required this.nama,
    this.posterUrl,
    required this.categorySlug,
    required this.categoryNama,
  });

  final int id;
  final String nama;
  final String? posterUrl;
  final String categorySlug;
  final String categoryNama;

  factory ListingEventSummary.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : const <String, dynamic>{};
    return ListingEventSummary(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      posterUrl: json['poster_url'] as String?,
      categorySlug: (cat['slug'] as String?) ?? '',
      categoryNama: (cat['nama'] as String?) ?? '',
    );
  }
}

/// Model ListingCard & ListingDetail sesuai docs/API.md.
class ListingItem {
  const ListingItem({
    required this.id,
    required this.event,
    required this.venueNama,
    required this.kota,
    required this.waktuAcara,
    required this.jenis,
    required this.tipe,
    this.seksi,
    required this.harga,
    this.hargaAsli,
    this.diskonPersen,
    required this.jumlahTersedia,
    required this.jumlahTerjual,
    required this.tertarik,
    required this.status,
    this.jarakKm,
    this.diperbarui,
    this.isFavorite = false,
    this.noKursi,
    this.izinkanWa = false,
    this.satuan = true,
    this.terikatNama = 'tidak',
    this.serahTerima = const [],
    this.lokasiPenjualKota,
    this.catatan,
    this.photos = const [],
    this.venue,
    this.seller,
    this.confirmedAt,
    this.createdAt,
    int? jumlahTotal,
  }) : _jumlahTotalExplicit = jumlahTotal;

  final int id;
  final ListingEventSummary event;
  final String venueNama;
  final String kota;
  final DateTime waktuAcara;
  final String jenis;
  final String tipe;
  final String? seksi;
  final int harga;
  final int? hargaAsli;
  final int? diskonPersen;
  final int jumlahTersedia;
  final int jumlahTerjual;
  final int tertarik;
  final String status;
  final double? jarakKm;
  final DateTime? diperbarui;
  final bool isFavorite;
  final String? noKursi;
  final bool izinkanWa;
  final bool satuan;
  final String terikatNama;
  final List<String> serahTerima;
  final String? lokasiPenjualKota;
  final String? catatan;
  final List<ListingPhotoItem> photos;
  final VenueItem? venue;
  final ListingSellerInfo? seller;
  final DateTime? confirmedAt;
  final DateTime? createdAt;
  final int? _jumlahTotalExplicit;

  int get jumlahTotal => _jumlahTotalExplicit ?? (jumlahTersedia + jumlahTerjual);

  ListingData toListingData() {
    return ListingData(
      id: id.toString(),
      eventName: event.nama,
      venueName: venueNama,
      city: kota,
      eventDate: waktuAcara,
      pricePerTicket: harga,
      ticketCount: jumlahTersedia,
      posterUrl: event.posterUrl,
      distanceKm: jarakKm,
      type: jenis == 'last_minute' ? TicketType.lastMinute : TicketType.limited,
      isSaved: isFavorite,
      discountPercent: diskonPersen,
      status: status,
    );
  }

  ListingItem copyWith({
    int? jumlahTersedia,
    int? jumlahTerjual,
    String? status,
    DateTime? confirmedAt,
    int? harga,
    int? hargaAsli,
    int? diskonPersen,
    String? catatan,
    bool? izinkanWa,
  }) {
    return ListingItem(
      id: id,
      event: event,
      venueNama: venueNama,
      kota: kota,
      waktuAcara: waktuAcara,
      jenis: jenis,
      tipe: tipe,
      seksi: seksi,
      harga: harga ?? this.harga,
      hargaAsli: hargaAsli ?? this.hargaAsli,
      diskonPersen: diskonPersen ?? this.diskonPersen,
      jumlahTersedia: jumlahTersedia ?? this.jumlahTersedia,
      jumlahTerjual: jumlahTerjual ?? this.jumlahTerjual,
      tertarik: tertarik,
      status: status ?? this.status,
      jarakKm: jarakKm,
      diperbarui: DateTime.now(),
      isFavorite: isFavorite,
      noKursi: noKursi,
      izinkanWa: izinkanWa ?? this.izinkanWa,
      satuan: satuan,
      terikatNama: terikatNama,
      serahTerima: serahTerima,
      lokasiPenjualKota: lokasiPenjualKota,
      catatan: catatan ?? this.catatan,
      photos: photos,
      venue: venue,
      seller: seller,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdAt: createdAt,
      jumlahTotal: _jumlahTotalExplicit ?? (this.jumlahTersedia + this.jumlahTerjual),
    );
  }

  factory ListingItem.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? const [];
    final rawSerah = json['serah_terima'] as List<dynamic>? ?? const [];
    return ListingItem(
      id: (json['id'] as num).toInt(),
      event: ListingEventSummary.fromJson(
        Map<String, dynamic>.from(json['event'] as Map),
      ),
      venueNama: (json['venue_nama'] as String?) ?? '-',
      kota: (json['kota'] as String?) ?? '-',
      waktuAcara: DateTime.parse(json['waktu_acara'] as String),
      jenis: json['jenis'] as String,
      tipe: json['tipe'] as String,
      seksi: json['seksi'] as String?,
      harga: (json['harga'] as num).toInt(),
      hargaAsli: (json['harga_asli'] as num?)?.toInt(),
      diskonPersen: (json['diskon_persen'] as num?)?.toInt(),
      jumlahTotal: (json['jumlah_total'] as num?)?.toInt(),
      jumlahTersedia: (json['jumlah_tersedia'] as num?)?.toInt() ?? 0,
      jumlahTerjual: (json['jumlah_terjual'] as num?)?.toInt() ?? 0,
      tertarik: (json['tertarik'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'tersedia',
      jarakKm: (json['jarak_km'] as num?)?.toDouble(),
      diperbarui: json['diperbarui'] is String
          ? DateTime.tryParse(json['diperbarui'] as String)
          : null,
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      noKursi: json['no_kursi'] as String?,
      izinkanWa: (json['izinkan_wa'] as bool?) ?? false,
      satuan: (json['satuan'] as bool?) ?? true,
      terikatNama: (json['terikat_nama'] as String?) ?? 'tidak',
      serahTerima: rawSerah.map((e) => e.toString()).toList(),
      lokasiPenjualKota: json['lokasi_penjual_kota'] as String?,
      catatan: json['catatan'] as String?,
      photos: rawPhotos
          .map((p) =>
              ListingPhotoItem.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      venue: json['venue'] is Map
          ? VenueItem.fromJson(Map<String, dynamic>.from(json['venue'] as Map))
          : null,
      seller: json['seller'] is Map
          ? ListingSellerInfo.fromJson(
              Map<String, dynamic>.from(json['seller'] as Map))
          : null,
      confirmedAt: json['confirmed_at'] is String
          ? DateTime.tryParse(json['confirmed_at'] as String)
          : null,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

