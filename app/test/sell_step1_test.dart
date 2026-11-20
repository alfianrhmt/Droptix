import 'dart:typed_data';
import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/features/events/event_models.dart';
import 'package:droptix/features/events/event_repository.dart';
import 'package:droptix/features/listings/listing_models.dart';
import 'package:droptix/features/listings/listing_repository.dart';
import 'package:droptix/features/sell/sell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepo extends AuthRepository {
  _FakeAuthRepo() : super(ApiClient(tokenStorage: TokenStorage()));

  @override
  Future<UserModel> getMe() async => const UserModel(
        id: 1,
        nama: 'Budi',
        email: 'budi@example.com',
        kota: 'Surabaya',
      );
}

class _Step1FakeEventRepo implements EventRepository {
  final List<VenueItem> venues = [
    const VenueItem(id: 10, nama: 'Stadion Gelora Bung Tomo', kota: 'Surabaya'),
  ];

  final multiDateEvent = EventItem(
    id: 99,
    nama: 'Soundrenaline 2026',
    category: const EventCategory(
      id: 1,
      slug: 'konser-festival',
      nama: 'Konser & Festival',
      ikon: 'music_note',
      urutan: 1,
    ),
    venue: const VenueItem(id: 10, nama: 'Stadion Gelora Bung Tomo', kota: 'Surabaya'),
    tanggal: DateTime(2026, 11, 28, 19, 0),
    tanggalOpsi: const ['2026-11-28', '2026-11-29', '2026-11-30'],
  );

  final wisataEvent = const EventItem(
    id: 100,
    nama: 'Tiket Masuk Jatim Park 3',
    category: EventCategory(
      id: 4,
      slug: 'wisata',
      nama: 'Wisata',
      ikon: 'attractions',
      urutan: 4,
    ),
    venue: VenueItem(id: 11, nama: 'Jatim Park 3', kota: 'Batu'),
    tanggal: null,
    tanggalOpsi: [],
  );

  final bioskopEvent = const EventItem(
    id: 101,
    nama: 'Avengers: Secret Wars',
    category: EventCategory(
      id: 2,
      slug: 'bioskop',
      nama: 'Bioskop',
      ikon: 'movie',
      urutan: 2,
    ),
    venue: null,
    tanggal: null,
    tanggalOpsi: [],
  );

  @override
  Future<List<EventCategory>> getCategories() async => [
        multiDateEvent.category,
        wisataEvent.category,
        bioskopEvent.category,
      ];

  @override
  Future<List<VenueItem>> getVenues({
    String? q,
    String? kota,
    String? userKota,
    double? lat,
    double? lng,
  }) async =>
      venues;

  @override
  Future<VenueItem> createVenue({
    required String nama,
    required String kota,
    String? alamat,
  }) async {
    final v = VenueItem(id: venues.length + 20, nama: nama, kota: kota, alamat: alamat);
    venues.add(v);
    return v;
  }

  @override
  Future<List<EventItem>> searchEvents({String? q, String? categorySlug}) async =>
      [multiDateEvent, wisataEvent, bioskopEvent];

  @override
  Future<EventItem> createEvent({
    required int categoryId,
    required String nama,
    String? posterUrl,
    int? venueId,
    DateTime? tanggal,
    List<String>? tanggalOpsi,
    bool force = false,
  }) async =>
      multiDateEvent;

  @override
  Future<String> uploadPoster(Uint8List bytes, {String filename = 'poster.png'}) async =>
      '/uploads/poster.png';

  @override
  Future<List<TrendingBanner>> getTrending({double? lat, double? lng}) async =>
      const [];
}

class _Step1FakeListingRepo implements ListingRepository {
  @override
  Future<ListingItem> createListing(Map<String, dynamic> payload) {
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
  Future<ListingItem> getListingDetail(int id, {double? lat, double? lng}) {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedListings> getListings({String? q, String? category, String? jenis, String? tipe, String? kota, double? lat, double? lng, int? maxKm, int? minHarga, int? maxHarga, String? tanggal, int? dalamJam, bool? tersedia, String? sort, int page = 1, int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedListings> getMyFavorites({double? lat, double? lng, int page = 1, int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingItem>> getMyListings({String? status, int page = 1, int limit = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> toggleFavorite(int id, bool currentStatus) {
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
  Future<String> uploadTicketPhoto(Uint8List bytes, {String filename = 'ticket.png'}) {
    throw UnimplementedError();
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Tahap 1: Pilih event multi tanggal -> otomatis isi venue & tampilkan chip tanggal tanpa kalender',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = TokenStorage();
    await storage.saveSession(
      'token-123',
      const UserModel(id: 1, nama: 'Budi', email: 'budi@example.com', kota: 'Surabaya'),
    );
    final auth = AuthController(repository: _FakeAuthRepo(), tokenStorage: storage);
    await auth.restoreSession();

    final fakeEventRepo = _Step1FakeEventRepo();
    final fakeListingRepo = _Step1FakeListingRepo();

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SellScreen(
              eventRepository: fakeEventRepo,
              listingRepository: fakeListingRepo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi bahwa sebelum memilih event, field venue dan tanggal TIDAK tampil
    expect(find.text('Venue'), findsNothing);
    expect(find.text('Tanggal acara'), findsNothing);
    expect(find.text('Jam acara'), findsNothing);
    expect(find.text('Pilih event terlebih dahulu untuk mengisi detail tiket.'), findsOneWidget);

    // 1. Ketuk pemilih event
    await tester.tap(find.text('Pilih atau tambah event...'));
    await tester.pumpAndSettle();

    // 2. Pilih Soundrenaline 2026 (konser multi tanggal)
    expect(find.text('Soundrenaline 2026'), findsOneWidget);
    // Verifikasi ada informasi venue dan tanggal di hasil pencarian event
    expect(find.textContaining('Stadion Gelora Bung Tomo, Surabaya'), findsOneWidget);
    expect(find.textContaining('28 Nov 2026 - 30 Nov 2026 (3 hari)'), findsOneWidget);

    await tester.tap(find.text('Soundrenaline 2026'));
    await tester.pumpAndSettle();

    // 3. Venue & Kota otomatis terisi dan tampil sebagai card terkunci
    expect(find.text('Stadion Gelora Bung Tomo'), findsOneWidget);
    expect(find.textContaining('Surabaya • Sesuai event'), findsOneWidget);

    // 4. Multi tanggal tampil sebagai tombol/chips, bukan kalender
    expect(find.text('Pilih tanggal tiket yang Anda miliki:'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));

    // Ketuk tanggal kedua (29 Nov 2026)
    final chips = find.byType(ChoiceChip);
    await tester.tap(chips.at(1));
    await tester.pumpAndSettle();

    // 5. Tombol jam acara tersedia khusus untuk penjual
    expect(find.text('Jam acara (wajib)'), findsOneWidget);
    expect(find.text('19:00 WIB'), findsOneWidget);

    // 6. Tombol lanjut berhasil ke langkah 2
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jual Tiket (2/5)'), findsOneWidget);
  });

  testWidgets(
      'Tahap 1: Ubah venue -> Tambah venue baru via dialog modal -> otomatis terpilih',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = TokenStorage();
    await storage.saveSession(
      'token-123',
      const UserModel(id: 1, nama: 'Budi', email: 'budi@example.com', kota: 'Surabaya'),
    );
    final auth = AuthController(repository: _FakeAuthRepo(), tokenStorage: storage);
    await auth.restoreSession();

    final fakeEventRepo = _Step1FakeEventRepo();
    final fakeListingRepo = _Step1FakeListingRepo();

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SellScreen(
              eventRepository: fakeEventRepo,
              listingRepository: fakeListingRepo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pilih event Soundrenaline
    await tester.tap(find.text('Pilih atau tambah event...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soundrenaline 2026'));
    await tester.pumpAndSettle();

    // Ketuk "Ubah venue"
    expect(find.text('Ubah venue'), findsOneWidget);
    await tester.tap(find.text('Ubah venue'));
    await tester.pumpAndSettle();

    // Pastikan tidak ada tombol redundan "Venue tidak ada? Tambah baru"
    expect(find.text('Venue tidak ada? Tambah baru'), findsNothing);

    // Buka modal pencarian venue
    expect(find.text('Cari atau pilih venue...'), findsOneWidget);
    await tester.tap(find.text('Cari atau pilih venue...'));
    await tester.pumpAndSettle();

    // Modal pencarian venue terbuka, ada tombol "Tambah Venue"
    expect(find.text('Tambah Venue'), findsOneWidget);
    await tester.tap(find.text('Tambah Venue'));
    await tester.pumpAndSettle();

    // Modal dialog tambah venue
    expect(find.text('Tambah Venue Baru'), findsOneWidget);
    final dialogTextFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogTextFields.at(0), 'Jatim International Expo');
    await tester.enterText(dialogTextFields.at(1), 'Surabaya');
    await tester.enterText(dialogTextFields.at(2), 'Jl. A. Yani No. 99');

    await tester.tap(find.text('Simpan Venue'));
    await tester.pumpAndSettle();

    // Dialog tertutup dan venue baru terpilih
    expect(find.text('Tambah Venue Baru'), findsNothing);
    expect(find.textContaining('Jatim International Expo'), findsOneWidget);
  });

  testWidgets(
      'Tahap 1: Pilih event bioskop -> venue & tanggal acara berstatus wajib',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = TokenStorage();
    await storage.saveSession(
      'token-123',
      const UserModel(id: 1, nama: 'Budi', email: 'budi@example.com', kota: 'Surabaya'),
    );
    final auth = AuthController(repository: _FakeAuthRepo(), tokenStorage: storage);
    await auth.restoreSession();

    final fakeEventRepo = _Step1FakeEventRepo();
    final fakeListingRepo = _Step1FakeListingRepo();

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SellScreen(
              eventRepository: fakeEventRepo,
              listingRepository: fakeListingRepo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Buka event picker dan pilih film bioskop
    await tester.tap(find.text('Pilih atau tambah event...'));
    await tester.pumpAndSettle();

    expect(find.text('Avengers: Secret Wars'), findsOneWidget);
    await tester.tap(find.text('Avengers: Secret Wars'));
    await tester.pumpAndSettle();

    // 2. Verifikasi status field untuk Bioskop: Venue, Tanggal, Jam WAJIB
    expect(find.text('Venue (wajib)'), findsOneWidget);
    expect(find.text('Tanggal acara (wajib)'), findsOneWidget);
    expect(find.text('Jam acara (wajib)'), findsOneWidget);

    // 3. Jika mencoba lanjut tanpa memilih venue, muncul error validasi
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih venue untuk kategori Bioskop.'), findsOneWidget);
  });
}
