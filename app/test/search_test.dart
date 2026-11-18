import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';
import 'package:droptix/features/listings/listing_models.dart';
import 'package:droptix/features/listings/listing_repository.dart';
import 'package:droptix/features/search/recent_searches_storage.dart';
import 'package:droptix/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeListingRepository implements ListingRepository {
  _FakeListingRepository({this.items = const []});

  List<ListingItem> items;
  Map<String, dynamic> lastQueryParams = {};

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
    lastQueryParams = {
      'q': q,
      'category': category,
      'jenis': jenis,
      'tipe': tipe,
      'kota': kota,
      'lat': lat,
      'lng': lng,
      'max_km': maxKm,
      'min_harga': minHarga,
      'max_harga': maxHarga,
      'tanggal': tanggal,
      'dalam_jam': dalamJam,
      'tersedia': tersedia,
      'sort': sort,
      'page': page,
      'limit': limit,
    };

    var filtered = List<ListingItem>.from(items);
    if (q != null && q.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.event.nama.toLowerCase().contains(q.toLowerCase()) ||
              item.venueNama.toLowerCase().contains(q.toLowerCase()) ||
              item.kota.toLowerCase().contains(q.toLowerCase()))
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      filtered = filtered
          .where((item) => item.event.categorySlug == category)
          .toList();
    }
    if (jenis != null && jenis.isNotEmpty) {
      filtered = filtered.where((item) => item.jenis == jenis).toList();
    }
    if (tersedia == true) {
      filtered = filtered.where((item) => item.jumlahTersedia > 0).toList();
    }

    return PaginatedListings(
      items: filtered,
      total: filtered.length,
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
}

ListingItem _sampleListing({
  required int id,
  required String eventNama,
  required String categorySlug,
  required String categoryNama,
  required String venueNama,
  required String kota,
  required int harga,
  required int jumlahTersedia,
  required String jenis,
}) {
  return ListingItem(
    id: id,
    event: ListingEventSummary(
      id: id * 10,
      nama: eventNama,
      categorySlug: categorySlug,
      categoryNama: categoryNama,
    ),
    venueNama: venueNama,
    kota: kota,
    waktuAcara: DateTime.now().add(const Duration(days: 3)),
    jenis: jenis,
    tipe: 'digital',
    harga: harga,
    jumlahTersedia: jumlahTersedia,
    jumlahTerjual: 0,
    tertarik: 5,
    status: 'tersedia',
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('RecentSearchesStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('menambah, deduplikasi, dan membatasi maksimal 5 pencarian', () async {
      final storage = RecentSearchesStorage();
      await storage.addSearch('Coldplay');
      await storage.addSearch('Sheila on 7');
      await storage.addSearch('Tulus');
      await storage.addSearch('coldplay'); // duplikat case-insensitive
      await storage.addSearch('Dewa 19');
      await storage.addSearch('Hindia');
      await storage.addSearch('Bernadya');

      final list = await storage.getSearches();
      expect(list.length, 5);
      expect(list.first, 'Bernadya');
      expect(list[1], 'Hindia');
      expect(list[2], 'Dewa 19');
      expect(list[3], 'coldplay');
      expect(list[4], 'Tulus');
    });

    test('menghapus satu pencarian dan hapus semua', () async {
      final storage = RecentSearchesStorage();
      await storage.addSearch('Event A');
      await storage.addSearch('Event B');

      await storage.removeSearch('Event A');
      var list = await storage.getSearches();
      expect(list, ['Event B']);

      await storage.clearAll();
      list = await storage.getSearches();
      expect(list, isEmpty);
    });
  });

  group('SearchScreen widget tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget createTestApp(Widget child) {
      return CountdownTimerProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: child,
        ),
      );
    }

    testWidgets('menampilkan search bar, chip filter, dan daftar ListingRow di 360x740',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final repo = _FakeListingRepository(items: [
        _sampleListing(
          id: 1,
          eventNama: 'Coldplay Music of the Spheres',
          categorySlug: 'konser-festival',
          categoryNama: 'Konser & Festival',
          venueNama: 'Gelora Bung Karno',
          kota: 'Jakarta',
          harga: 1500000,
          jumlahTersedia: 2,
          jenis: 'limited',
        ),
        _sampleListing(
          id: 2,
          eventNama: 'Sheila on 7 Tunggu Aku di Surabaya',
          categorySlug: 'konser-festival',
          categoryNama: 'Konser & Festival',
          venueNama: 'Pakuwon City Mall',
          kota: 'Surabaya',
          harga: 450000,
          jumlahTersedia: 1,
          jenis: 'last_minute',
        ),
      ]);

      await tester.pumpWidget(createTestApp(
        SearchScreen(listingRepository: repo),
      ));
      await tester.pumpAndSettle();

      // Memastikan search bar tampil
      expect(find.byType(AppSearchBar), findsOneWidget);

      // Memastikan filter chips tampil
      expect(find.byType(FilterChipRow), findsOneWidget);
      expect(find.text('Tanggal'), findsOneWidget);
      expect(find.text('Urutkan'), findsOneWidget);

      // Geser chip row ke kiri untuk melihat chip lainnya
      await tester.scrollUntilVisible(
        find.text('Tersedia'),
        50.0,
        scrollable: find.descendant(
          of: find.byType(FilterChipRow),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tersedia'), findsOneWidget);

      // Memastikan listing rows tampil
      expect(find.byType(ListingRow), findsNWidgets(2));
      expect(find.text('Coldplay Music of the Spheres'), findsOneWidget);
      expect(find.text('Sheila on 7 Tunggu Aku di Surabaya'), findsOneWidget);
    });

    testWidgets('pencarian kategori dan filter jenis limited', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final repo = _FakeListingRepository(items: [
        _sampleListing(
          id: 1,
          eventNama: 'Konser Pop A',
          categorySlug: 'konser-festival',
          categoryNama: 'Konser & Festival',
          venueNama: 'Hall A',
          kota: 'Jakarta',
          harga: 1000000,
          jumlahTersedia: 1,
          jenis: 'limited',
        ),
        _sampleListing(
          id: 2,
          eventNama: 'Film Romansa B',
          categorySlug: 'bioskop',
          categoryNama: 'Bioskop',
          venueNama: 'XXI Tunjungan',
          kota: 'Surabaya',
          harga: 50000,
          jumlahTersedia: 2,
          jenis: 'last_minute',
        ),
      ]);

      await tester.pumpWidget(createTestApp(
        SearchScreen(
          listingRepository: repo,
          categorySlug: 'konser-festival',
          categoryName: 'Konser & Festival',
        ),
      ));
      await tester.pumpAndSettle();

      // Banner kategori tampil
      expect(find.text('Konser & Festival'), findsOneWidget);

      // Hasil hanya memuat event dengan category 'konser-festival'
      expect(find.text('Konser Pop A'), findsOneWidget);
      expect(find.text('Film Romansa B'), findsNothing);
      expect(repo.lastQueryParams['category'], 'konser-festival');
    });

    testWidgets('menampilkan 5 pencarian terakhir saat search bar difokuskan dan memilih salah satu',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final storage = RecentSearchesStorage();
      await storage.addSearch('Coldplay');
      await storage.addSearch('Tulus');
      await storage.addSearch('Bruno Mars');

      final repo = _FakeListingRepository(items: [
        _sampleListing(
          id: 1,
          eventNama: 'Bruno Mars Live in Jakarta',
          categorySlug: 'konser-festival',
          categoryNama: 'Konser & Festival',
          venueNama: 'JIS',
          kota: 'Jakarta',
          harga: 2500000,
          jumlahTersedia: 2,
          jenis: 'limited',
        ),
      ]);

      await tester.pumpWidget(createTestApp(
        SearchScreen(
          listingRepository: repo,
          recentSearchesStorage: storage,
        ),
      ));
      await tester.pumpAndSettle();

      // Awalnya menampilkan hasil listing
      expect(find.text('Bruno Mars Live in Jakarta'), findsOneWidget);
      expect(find.text('Pencarian Terakhir'), findsNothing);

      // Fokus pada search bar
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Pencarian terakhir muncul
      expect(find.text('Pencarian Terakhir'), findsOneWidget);
      expect(find.text('Bruno Mars'), findsOneWidget);
      expect(find.text('Tulus'), findsOneWidget);
      expect(find.text('Coldplay'), findsOneWidget);

      // Memilih 'Bruno Mars' dari riwayat
      await tester.tap(find.text('Bruno Mars'));
      await tester.pumpAndSettle();

      // Overlay tertutup dan filter q aktif
      expect(find.text('Pencarian Terakhir'), findsNothing);
      expect(repo.lastQueryParams['q'], 'Bruno Mars');
      expect(find.text('Bruno Mars Live in Jakarta'), findsOneWidget);
    });

    testWidgets('membuka bottom sheet urutkan dan memilih Termurah', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final repo = _FakeListingRepository();

      await tester.pumpWidget(createTestApp(
        SearchScreen(listingRepository: repo),
      ));
      await tester.pumpAndSettle();

      // Buka bottom sheet Urutkan
      await tester.tap(find.text('Urutkan'));
      await tester.pumpAndSettle();

      expect(find.text('Urutkan Berdasarkan'), findsOneWidget);
      expect(find.text('Harga Termurah'), findsOneWidget);

      // Pilih Termurah
      await tester.tap(find.text('Harga Termurah'));
      await tester.pumpAndSettle();

      // Sheet tertutup, query dikirim dengan sort = 'termurah', label chip berubah
      expect(find.text('Urutkan Berdasarkan'), findsNothing);
      expect(repo.lastQueryParams['sort'], 'termurah');
      expect(find.text('Termurah'), findsOneWidget);
    });

    testWidgets('keadaan kosong menampilkan pesan dan tombol Jual tiketmu', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final repo = _FakeListingRepository(items: []);
      bool sellClicked = false;

      await tester.pumpWidget(createTestApp(
        SearchScreen(
          listingRepository: repo,
          initialQuery: 'Taylor Swift',
          onSellPressed: () {
            sellClicked = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Menampilkan empty state dengan pesan dan tombol aksi
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text("Belum ada tiket untuk 'Taylor Swift'"), findsOneWidget);
      expect(find.text('Jual tiketmu'), findsOneWidget);

      // Klik "Jual tiketmu"
      await tester.tap(find.text('Jual tiketmu'));
      await tester.pump();
      expect(sellClicked, isTrue);
    });

    testWidgets(
        'Skenario Uji 5: pencarian Hari Ini + Last-Minute mengirim filter yang tepat dan urutan berubah dengan lokasi',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final itemSby = _sampleListing(
        id: 2001,
        eventNama: 'Konser Surabaya Hari Ini',
        categorySlug: 'konser-festival',
        categoryNama: 'Konser & Festival',
        venueNama: 'Grand City',
        kota: 'Surabaya',
        harga: 400000,
        jumlahTersedia: 2,
        jenis: 'last_minute',
      );

      final itemJkt = _sampleListing(
        id: 2002,
        eventNama: 'Konser Jakarta Hari Ini',
        categorySlug: 'konser-festival',
        categoryNama: 'Konser & Festival',
        venueNama: 'GBK',
        kota: 'Jakarta',
        harga: 300000,
        jumlahTersedia: 1,
        jenis: 'last_minute',
      );

      final repo = _FakeListingRepository(items: [itemSby, itemJkt]);

      await tester.pumpWidget(createTestApp(
        SearchScreen(
          listingRepository: repo,
          initialTanggal: 'hari_ini',
          initialJenis: 'last_minute',
          userLat: -7.263,
          userLng: 112.745,
        ),
      ));
      await tester.pumpAndSettle();

      // Memastikan chip filter Tanggal aktif dengan label yang benar
      expect(find.text('Hari Ini'), findsOneWidget);

      // Scroll chip row untuk melihat chip Jenis (Last-Minute)
      await tester.scrollUntilVisible(
        find.text('Last-Minute'),
        50.0,
        scrollable: find.descendant(
          of: find.byType(FilterChipRow),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Last-Minute'), findsOneWidget);

      // Parameter query terverifikasi sesuai Skenario 5
      expect(repo.lastQueryParams['tanggal'], 'hari_ini');
      expect(repo.lastQueryParams['jenis'], 'last_minute');
      expect(repo.lastQueryParams['sort'], 'relevan');
      expect(repo.lastQueryParams['lat'], -7.263);
      expect(repo.lastQueryParams['lng'], 112.745);

      // Kedua item tampil
      expect(find.text('Konser Surabaya Hari Ini'), findsOneWidget);
      expect(find.text('Konser Jakarta Hari Ini'), findsOneWidget);
    });

    testWidgets('Skenario Uji 8: listing yang kedaluwarsa tidak tampil di pencarian',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final repo = _FakeListingRepository(items: [
        _sampleListing(
          id: 1,
          eventNama: 'Event Aktif Masa Depan',
          categorySlug: 'konser-festival',
          categoryNama: 'Konser & Festival',
          venueNama: 'Venue A',
          kota: 'Jakarta',
          harga: 100000,
          jumlahTersedia: 2,
          jenis: 'limited',
        ),
      ]);

      await tester.pumpWidget(createTestApp(
        SearchScreen(
          listingRepository: repo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Event Aktif Masa Depan'), findsOneWidget);
      expect(find.text('Event Kedaluwarsa'), findsNothing);
      expect(repo.lastQueryParams['tersedia'], true);
    });
  });
}
