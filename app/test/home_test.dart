import 'package:droptix/core/location/location_controller.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';
import 'package:droptix/features/events/event_models.dart';
import 'package:droptix/features/events/event_repository.dart';
import 'package:droptix/features/home/home_screen.dart';
import 'package:droptix/features/listings/listing_models.dart';
import 'package:droptix/features/listings/listing_repository.dart';
import 'package:droptix/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeListingRepository implements ListingRepository {
  _FakeListingRepository({
    this.nearbyItems = const [],
    this.endingSoonItems = const [],
    this.recentItems = const [],
  });

  List<ListingItem> nearbyItems;
  List<ListingItem> endingSoonItems;
  List<ListingItem> recentItems;

  List<Map<String, dynamic>> callHistory = [];

  @override
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
    callHistory.add({
      'q': q,
      'category': category,
      'jenis': jenis,
      'kota': kota,
      'lat': lat,
      'lng': lng,
      'max_km': maxKm,
      'tanggal': tanggal,
      'dalam_jam': dalamJam,
      'tersedia': tersedia,
      'sort': sort,
      'page': page,
      'limit': limit,
    });

    if (dalamJam == 24 && sort == 'segera') {
      return PaginatedListings(
        items: endingSoonItems,
        total: endingSoonItems.length,
        page: page,
        limit: limit,
      );
    }

    if (sort == 'terdekat' || (kota != null && sort == 'segera')) {
      return PaginatedListings(
        items: nearbyItems,
        total: nearbyItems.length,
        page: page,
        limit: limit,
      );
    }

    if (sort == 'terbaru') {
      return PaginatedListings(
        items: recentItems,
        total: 50, // mensimulasikan total 50 untuk menguji pagination
        page: page,
        limit: limit,
      );
    }

    return PaginatedListings(
      items: const [],
      total: 0,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<ListingItem>> getMyListings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async =>
      const [];

  @override
  Future<ListingItem> createListing(Map<String, dynamic> payload) {
    throw UnimplementedError();
  }

  @override
  Future<ListingItem> getListingDetail(int id, {double? lat, double? lng}) {
    throw UnimplementedError();
  }

  @override
  Future<ListingItem> updateListing(int id, Map<String, dynamic> payload) {
    throw UnimplementedError();
  }

  @override
  Future<ListingItem> updateStock(int id, int jumlahTerjual) {
    throw UnimplementedError();
  }

  @override
  Future<DateTime> confirmListing(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteListing(int id) {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadTicketPhoto(dynamic bytes, {String filename = 'ticket.png'}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> toggleFavorite(int id, bool currentStatus) async => !currentStatus;

  @override
  Future<PaginatedListings> getMyFavorites({double? lat, double? lng, int page = 1, int limit = 20}) async =>
      const PaginatedListings(items: [], total: 0, page: 1, limit: 20);
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({this.trendingBanners = const []});

  List<TrendingBanner> trendingBanners;
  double? lastLat;
  double? lastLng;

  @override
  Future<List<TrendingBanner>> getTrending({double? lat, double? lng}) async {
    lastLat = lat;
    lastLng = lng;
    return trendingBanners;
  }

  @override
  Future<List<EventCategory>> getCategories() async => const [];

  @override
  Future<List<VenueItem>> getVenues({
    String? q,
    String? kota,
    String? userKota,
    double? lat,
    double? lng,
  }) async =>
      const [];

  @override
  Future<List<EventItem>> searchEvents({String? q, String? categorySlug}) async =>
      const [];

  @override
  Future<VenueItem> createVenue({
    required String nama,
    required String kota,
    String? alamat,
  }) async {
    throw UnimplementedError();
  }

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
}

ListingItem _sampleListing({
  required int id,
  required String eventNama,
  required String categorySlug,
  required String venueNama,
  required String kota,
  required int harga,
  required int jumlahTersedia,
  required String jenis,
  double? jarakKm,
}) {
  return ListingItem(
    id: id,
    event: ListingEventSummary(
      id: id * 10,
      nama: eventNama,
      categorySlug: categorySlug,
      categoryNama: categorySlug,
    ),
    venueNama: venueNama,
    kota: kota,
    waktuAcara: DateTime.now().add(const Duration(hours: 18)),
    jenis: jenis,
    tipe: 'digital',
    harga: harga,
    jumlahTersedia: jumlahTersedia,
    jumlahTerjual: 0,
    tertarik: 3,
    status: 'tersedia',
    jarakKm: jarakKm,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('HomeScreen widget tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget createTestApp({
      required Widget child,
      LocationController? locationController,
    }) {
      return LocationScope(
        controller: locationController ?? LocationController(),
        child: CountdownTimerProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: child,
          ),
        ),
      );
    }

    testWidgets(
        'menampilkan semua section Home sesuai DESIGN.md di 360x740 tanpa overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final listingRepo = _FakeListingRepository(
        nearbyItems: [
          _sampleListing(
            id: 1,
            eventNama: 'Coldplay Music of the Spheres',
            categorySlug: 'konser-festival',
            venueNama: 'GBK Senayan',
            kota: 'Jakarta',
            harga: 1500000,
            jumlahTersedia: 2,
            jenis: 'limited',
            jarakKm: 4.2,
          ),
        ],
        endingSoonItems: [
          _sampleListing(
            id: 2,
            eventNama: 'Film Agak Laen',
            categorySlug: 'bioskop',
            venueNama: 'XXI Grand City',
            kota: 'Surabaya',
            harga: 45000,
            jumlahTersedia: 1,
            jenis: 'last_minute',
          ),
        ],
        recentItems: [
          _sampleListing(
            id: 3,
            eventNama: 'Dewa 19 All Stars Stadium Tour',
            categorySlug: 'konser-festival',
            venueNama: 'Stadion Gelora 10 Nopember',
            kota: 'Surabaya',
            harga: 650000,
            jumlahTersedia: 3,
            jenis: 'limited',
          ),
        ],
      );

      final eventRepo = _FakeEventRepository(
        trendingBanners: [
          const TrendingBanner(
            type: 'event',
            categorySlug: 'konser-festival',
            event: ListingEventSummary(
              id: 100,
              nama: 'Festival Nada Musim Panas',
              categorySlug: 'konser-festival',
              categoryNama: 'Konser & Festival',
            ),
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        child: HomeScreen(
          listingRepository: listingRepo,
          eventRepository: eventRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // 1. AppHeader
      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Droptix'), findsOneWidget);

      // 2. SearchBar
      expect(find.byType(AppSearchBar), findsOneWidget);

      // 3. BannerCarousel
      expect(find.byType(BannerCarousel), findsOneWidget);

      // 4. ResellTypeTiles
      expect(find.byType(ResellTypeTiles), findsOneWidget);
      expect(find.text('Limited'), findsOneWidget);
      expect(find.text('Last-Minute'), findsOneWidget);

      // 5. QuickDateGrid telah dihapus dari Home
      expect(find.byType(QuickDateGrid), findsNothing);

      // 6. CategoryRow
      expect(find.byType(CategoryRow), findsOneWidget);
      expect(find.text('Konser & Festival'), findsOneWidget);

      // 7. Dekat Kamu
      expect(find.text('Dekat Kamu'), findsOneWidget);
      expect(find.byType(PosterCard), findsOneWidget);

      // 8. Segera Berakhir
      expect(find.text('Segera Berakhir'), findsOneWidget);
      expect(find.text('Film Agak Laen'), findsOneWidget);

      // 9. Baru Ditambahkan
      expect(find.text('Baru Ditambahkan'), findsOneWidget);
      expect(find.text('Dewa 19 All Stars Stadium Tour'), findsOneWidget);
    });

    testWidgets('mengetuk search bar membuka SearchScreen', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final listingRepo = _FakeListingRepository();
      final eventRepo = _FakeEventRepository();

      await tester.pumpWidget(createTestApp(
        child: HomeScreen(
          listingRepository: listingRepo,
          eventRepository: eventRepo,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppSearchBar));
      await tester.pumpAndSettle();

      // Memastikan SearchScreen terbuka
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('mengetuk tile Limited membuka pencarian jenis limited',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final listingRepo = _FakeListingRepository();
      final eventRepo = _FakeEventRepository();
      String? tappedResellType;

      await tester.pumpWidget(createTestApp(
        child: HomeScreen(
          listingRepository: listingRepo,
          eventRepository: eventRepo,
          onResellTypeTap: (type) {
            tappedResellType = type;
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Limited'));
      await tester.pumpAndSettle();

      expect(tappedResellType, 'limited');
    });

    testWidgets('mengetuk kategori Bioskop memanggil callback onCategoryTap',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final listingRepo = _FakeListingRepository();
      final eventRepo = _FakeEventRepository();
      String? chosenSlug;

      await tester.pumpWidget(createTestApp(
        child: HomeScreen(
          listingRepository: listingRepo,
          eventRepository: eventRepo,
          onCategoryTap: (slug, name) {
            chosenSlug = slug;
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bioskop'));
      await tester.pumpAndSettle();

      expect(chosenSlug, 'bioskop');
    });

    testWidgets('menampilkan keadaan kosong saat tidak ada tiket dekat atau segera berakhir',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final listingRepo = _FakeListingRepository(
        nearbyItems: [],
        endingSoonItems: [],
        recentItems: [],
      );
      final eventRepo = _FakeEventRepository(trendingBanners: []);

      await tester.pumpWidget(createTestApp(
        child: HomeScreen(
          listingRepository: listingRepo,
          eventRepository: eventRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // Empty states tidak merusak layout
      expect(find.text('Belum ada tiket di sekitar Surabaya.'), findsOneWidget);
      expect(
          find.text('Tidak ada acara yang segera berakhir dalam 24 jam.'),
          findsOneWidget);
      expect(
          find.text('Belum ada tiket yang baru ditambahkan.'), findsOneWidget);
    });

    testWidgets('scroll tanpa batas memuat halaman berikutnya pada Baru Ditambahkan',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final listingRepo = _FakeListingRepository(
        recentItems: List.generate(
          10,
          (i) => _sampleListing(
            id: i + 1,
            eventNama: 'Konser Indah #$i',
            categorySlug: 'konser-festival',
            venueNama: 'Hall $i',
            kota: 'Jakarta',
            harga: 100000 + i * 50000,
            jumlahTersedia: 2,
            jenis: 'limited',
          ),
        ),
      );
      final eventRepo = _FakeEventRepository();

      await tester.pumpWidget(createTestApp(
        child: HomeScreen(
          listingRepository: listingRepo,
          eventRepository: eventRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // Awalnya dipanggil page 1
      final pageCallsInitial = listingRepo.callHistory
          .where((c) => c['sort'] == 'terbaru')
          .toList();
      expect(pageCallsInitial.length, 1);
      expect(pageCallsInitial.first['page'], 1);

      // Scroll ke bagian bawah menggunakan vertical Scrollable
      await tester.drag(
        find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.vertical),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();

      // Halaman 2 dipanggil
      final pageCallsAfterScroll = listingRepo.callHistory
          .where((c) => c['sort'] == 'terbaru')
          .toList();
      expect(pageCallsAfterScroll.length, greaterThanOrEqualTo(2));
      expect(pageCallsAfterScroll[1]['page'], 2);
    });
  });
}
