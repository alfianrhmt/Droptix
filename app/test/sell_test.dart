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

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(tokenStorage: TokenStorage()));

  @override
  Future<UserModel> getMe() async {
    return const UserModel(
      id: 1,
      nama: 'Rina',
      email: 'rina@example.com',
      noWa: '6281234567890',
      kota: 'Surabaya',
    );
  }
}

class _FakeEventRepository implements EventRepository {
  final testEvent = EventItem(
    id: 7,
    nama: 'Nada Senja Live in Surabaya',
    category: const EventCategory(
      id: 1,
      slug: 'konser-festival',
      nama: 'Konser & Festival',
      ikon: 'music_note',
      urutan: 1,
    ),
    venue: const VenueItem(
      id: 3,
      nama: 'Grand City Convention Hall',
      kota: 'Surabaya',
      lat: -7.262,
      lng: 112.751,
    ),
    tanggal: DateTime.now().add(const Duration(days: 5)),
  );

  @override
  Future<List<EventCategory>> getCategories() async => [testEvent.category];

  @override
  Future<List<VenueItem>> getVenues({String? q, String? kota}) async => [
        const VenueItem(
          id: 3,
          nama: 'Grand City Convention Hall',
          kota: 'Surabaya',
          lat: -7.262,
          lng: 112.751,
        ),
      ];

  @override
  Future<List<EventItem>> searchEvents({String? q, String? categorySlug}) async =>
      [testEvent];

  @override
  Future<EventItem> createEvent({
    required int categoryId,
    required String nama,
    String? posterUrl,
    int? venueId,
    DateTime? tanggal,
    bool force = false,
  }) async =>
      testEvent;

  @override
  Future<String> uploadPoster(Uint8List bytes, {String filename = 'poster.png'}) async =>
      '/uploads/poster.png';
}

class _FakeListingRepository implements ListingRepository {
  Map<String, dynamic>? createdPayload;

  @override
  Future<List<ListingItem>> getMyListings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async =>
      const [];

  @override
  Future<ListingItem> createListing(Map<String, dynamic> payload) async {
    createdPayload = payload;
    return ListingItem(
      id: 42,
      event: const ListingEventSummary(
        id: 7,
        nama: 'Nada Senja Live in Surabaya',
        categorySlug: 'konser-festival',
        categoryNama: 'Konser & Festival',
      ),
      venueNama: 'Grand City Convention Hall',
      kota: 'Surabaya',
      waktuAcara: DateTime.parse(payload['waktu_acara'] as String),
      jenis: payload['jenis'] as String,
      tipe: payload['tipe'] as String,
      harga: payload['harga'] as int,
      jumlahTersedia: payload['jumlah_total'] as int,
      jumlahTerjual: 0,
      tertarik: 0,
      status: 'tersedia',
      izinkanWa: payload['izinkan_wa'] as bool,
    );
  }

  @override
  Future<String> uploadTicketPhoto(Uint8List bytes,
          {String filename = 'ticket.png'}) async =>
      '/uploads/ticket1.png';

  @override
  Future<DateTime> confirmListing(int id) async => DateTime.now();

  @override
  Future<void> deleteListing(int id) async {}

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
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'SellScreen menjalankan alur 5 langkah + sakelar WA + pratinjau + posting di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = TokenStorage();
    await storage.saveSession(
      'jwt-123',
      const UserModel(
        id: 1,
        nama: 'Rina',
        email: 'rina@example.com',
        noWa: '6281234567890',
        kota: 'Surabaya',
      ),
    );

    final auth = AuthController(
      repository: _FakeAuthRepository(),
      tokenStorage: storage,
    );
    await auth.restoreSession();

    final fakeEventRepo = _FakeEventRepository();
    final fakeListingRepo = _FakeListingRepository();
    var posted = false;

    // 1x1 PNG bytes
    final samplePng = Uint8List.fromList([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
      0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
      0x42, 0x60, 0x82,
    ]);

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SellScreen(
              eventRepository: fakeEventRepo,
              listingRepository: fakeListingRepo,
              pickPhotoBytes: () async => samplePng,
              onPosted: () => posted = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Langkah 1: Pilih event
    expect(find.textContaining('Jual Tiket (1/5)'), findsOneWidget);
    await tester.tap(find.text('Pilih atau tambah event...'));
    await tester.pumpAndSettle();
    expect(find.text('Nada Senja Live in Surabaya'), findsOneWidget);
    await tester.tap(find.text('Nada Senja Live in Surabaya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Langkah 2: Jenis & Tipe
    expect(find.textContaining('Jual Tiket (2/5)'), findsOneWidget);
    await tester.tap(find.text('Last-Minute'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Langkah 3: Harga & Jumlah
    expect(find.textContaining('Jual Tiket (3/5)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '450000');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Langkah 4: Serah terima
    expect(find.textContaining('Jual Tiket (4/5)'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Langkah 5: Foto & WhatsApp
    expect(find.textContaining('Jual Tiket (5/5)'), findsOneWidget);
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Pratinjau & Posting
    expect(find.text('Pratinjau Listing'), findsOneWidget);
    expect(find.text('Rp 450000'), findsOneWidget);
    await tester.tap(find.text('Posting Tiket'));
    await tester.pumpAndSettle();

    expect(posted, isTrue);
    expect(fakeListingRepo.createdPayload, isNotNull);
    expect(fakeListingRepo.createdPayload!['jenis'], 'last_minute');
    expect(fakeListingRepo.createdPayload!['izinkan_wa'], isFalse);
    expect(fakeListingRepo.createdPayload!['photos'], ['/uploads/ticket1.png']);
    expect(tester.takeException(), isNull);
  });
}
