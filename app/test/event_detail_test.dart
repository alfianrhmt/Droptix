import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droptix/features/events/event_detail_screen.dart';
import 'package:droptix/features/events/event_models.dart';
import 'package:droptix/features/events/event_repository.dart';
import 'package:droptix/features/listings/listing_models.dart';

class _FakeEventDetailRepo implements EventRepository {
  _FakeEventDetailRepo({
    required this.detailToReturn,
    bool initialAlert = false,
  }) : isAlertActive = initialAlert;

  EventDetailModel detailToReturn;
  bool isAlertActive;
  String? lastSort;

  @override
  Future<EventDetailModel> getEventDetail(
    int id, {
    String? sort,
    double? lat,
    double? lng,
    int? venueId,
    String? tanggal,
  }) async {
    lastSort = sort;
    return detailToReturn.copyWith(isAlertActive: isAlertActive);
  }

  @override
  Future<bool> toggleEventAlert(int eventId) async {
    isAlertActive = !isAlertActive;
    return isAlertActive;
  }

  @override
  Future<List<EventCategory>> getCategories() async => const [];
  @override
  Future<List<VenueItem>> getVenues({String? q, String? kota, String? userKota, double? lat, double? lng}) async => const [];
  @override
  Future<VenueItem> createVenue({required String nama, required String kota, String? alamat}) {
    throw UnimplementedError();
  }
  @override
  Future<List<EventItem>> searchEvents({String? q, String? categorySlug}) async => const [];
  @override
  Future<EventItem> createEvent({
    required int categoryId,
    required String nama,
    String? posterUrl,
    int? venueId,
    DateTime? tanggal,
    List<String>? tanggalOpsi,
    bool force = false,
  }) {
    throw UnimplementedError();
  }
  @override
  Future<String> uploadPoster(dynamic bytes, {String filename = 'poster.png'}) {
    throw UnimplementedError();
  }
  @override
  Future<List<TrendingBanner>> getTrending({double? lat, double? lng}) async => const [];
  @override
  Future<List<AppBanner>> getBanners() async => const [];
  @override
  Future<List<PopularEventItem>> getPopularEvents() async => const [];
}

void main() {
  final sampleEvent = EventItem(
    id: 1,
    nama: 'Avengers: Doomsday',
    category: const EventCategory(
      id: 2,
      slug: 'bioskop',
      nama: 'Bioskop',
      ikon: 'movie',
      urutan: 2,
    ),
    venue: const VenueItem(id: 10, nama: 'Cinema XXI Tunjungan Plaza', kota: 'Surabaya'),
    tanggal: DateTime(2026, 12, 1, 19, 30),
    tanggalOpsi: const ['2026-12-01'],
  );

  final sampleListing = ListingItem(
    id: 101,
    event: ListingEventSummary(
      id: 1,
      nama: 'Avengers: Doomsday',
      categorySlug: 'bioskop',
      categoryNama: 'Bioskop',
    ),
    venueNama: 'Cinema XXI Tunjungan Plaza',
    kota: 'Surabaya',
    waktuAcara: DateTime(2026, 12, 1, 19, 30),
    jenis: 'last_minute',
    tipe: 'digital',
    seksi: 'Studio 1',
    noKursi: 'F12, F13',
    harga: 50000,
    hargaAsli: 65000,
    diskonPersen: 23,
    jumlahTersedia: 2,
    jumlahTerjual: 0,
    tertarik: 4,
    status: 'tersedia',
    seller: ListingSellerInfo(
      id: 1,
      nama: 'Alfian',
      username: 'al.viannr',
      bergabung: DateTime(2026, 1, 1),
    ),
  );

  testWidgets('Menampilkan ringkasan event, kotak stats, dan daftar tiket', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeRepo = _FakeEventDetailRepo(
      detailToReturn: EventDetailModel(
        event: sampleEvent,
        stats: const EventStatsModel(
          availableTicketsCount: 2,
          minPrice: 50000,
          maxPrice: 50000,
          sellersCount: 1,
        ),
        isAlertActive: false,
        listings: [sampleListing],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          eventId: 1,
          eventRepository: fakeRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi judul event
    expect(find.text('Avengers: Doomsday'), findsWidgets);
    expect(find.text('Bioskop'), findsOneWidget);

    // 2. Verifikasi kotak statistik
    expect(find.text('2'), findsOneWidget); // Tiket Tersedia
    expect(find.text('Tiket Tersedia'), findsOneWidget);
    expect(find.text('Harga Mulai'), findsOneWidget);
    expect(find.text('Rp 50.000'), findsWidgets);
    expect(find.text('Penjual Aktif'), findsOneWidget);

    // 3. Verifikasi aksi
    expect(find.text('Pantau Tiket'), findsOneWidget);
    expect(find.text('Jual Tiket'), findsOneWidget);

    // 4. Verifikasi kartu tiket
    expect(find.text('@al.viannr'), findsOneWidget);
    expect(find.text('Studio 1 · Kursi F12, F13'), findsOneWidget);
    expect(find.text('Cinema XXI Tunjungan Plaza, Surabaya'), findsWidgets);
  });

  testWidgets('Mengubah urutan filter memicu pemanggilan API getEventDetail dengan sort baru', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeRepo = _FakeEventDetailRepo(
      detailToReturn: EventDetailModel(
        event: sampleEvent,
        stats: const EventStatsModel(
          availableTicketsCount: 2,
          minPrice: 50000,
          maxPrice: 50000,
          sellersCount: 1,
        ),
        isAlertActive: false,
        listings: [sampleListing],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          eventId: 1,
          eventRepository: fakeRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap chip 'Terdekat'
    await tester.tap(find.text('Terdekat'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastSort, 'terdekat');
  });

  testWidgets('Menampilkan empty state jika event belum memiliki tiket yang dijual', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeRepo = _FakeEventDetailRepo(
      detailToReturn: EventDetailModel(
        event: sampleEvent,
        stats: const EventStatsModel(
          availableTicketsCount: 0,
          minPrice: null,
          maxPrice: null,
          sellersCount: 0,
        ),
        isAlertActive: false,
        listings: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          eventId: 1,
          eventRepository: fakeRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum Ada Tiket yang Dijual'), findsOneWidget);
    expect(find.text('Jual Tiket Acara Ini'), findsOneWidget);
  });
}
