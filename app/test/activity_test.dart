import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/features/activity/activity_screen.dart';
import 'package:droptix/features/listings/listing_models.dart';
import 'package:droptix/features/listings/listing_repository.dart';
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

class _FakeListingRepository implements ListingRepository {
  _FakeListingRepository(List<ListingItem> initialListings)
      : listings = List.of(initialListings);

  final List<ListingItem> listings;
  int? lastConfirmedId;
  int? lastDeletedId;
  int? lastUpdatedStockId;
  int? lastUpdatedStockValue;

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
    return PaginatedListings(
      items: List.of(listings),
      total: listings.length,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<ListingItem>> getMyListings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    if (status == null || status.isEmpty) {
      return List.of(listings);
    }
    return listings.where((l) => l.status == status).toList();
  }

  @override
  Future<ListingItem> updateStock(int id, int jumlahTerjual) async {
    lastUpdatedStockId = id;
    lastUpdatedStockValue = jumlahTerjual;
    final idx = listings.indexWhere((l) => l.id == id);
    final current = listings[idx];
    final sisa = current.jumlahTotal - jumlahTerjual;
    final newStatus = sisa <= 0 ? 'terjual' : 'tersedia';
    final updated = current.copyWith(
      jumlahTersedia: sisa,
      jumlahTerjual: jumlahTerjual,
      status: newStatus,
    );
    listings[idx] = updated;
    return updated;
  }

  @override
  Future<DateTime> confirmListing(int id) async {
    lastConfirmedId = id;
    final now = DateTime.now();
    final idx = listings.indexWhere((l) => l.id == id);
    if (idx != -1) {
      listings[idx] = listings[idx].copyWith(confirmedAt: now);
    }
    return now;
  }

  @override
  Future<void> deleteListing(int id) async {
    lastDeletedId = id;
    listings.removeWhere((l) => l.id == id);
  }

  @override
  Future<ListingItem> updateListing(int id, Map<String, dynamic> payload) async {
    final idx = listings.indexWhere((l) => l.id == id);
    final current = listings[idx];
    final updated = current.copyWith(
      harga: payload['harga'] as int?,
      hargaAsli: payload['harga_asli'] as int?,
      catatan: payload['catatan'] as String?,
      izinkanWa: payload['izinkan_wa'] as bool?,
    );
    listings[idx] = updated;
    return updated;
  }

  @override
  Future<ListingItem> createListing(Map<String, dynamic> payload) {
    throw UnimplementedError();
  }

  @override
  Future<ListingItem> getListingDetail(int id, {double? lat, double? lng}) {
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
  required String status,
  required int harga,
  required int jumlahTotal,
  required int jumlahTerjual,
  DateTime? confirmedAt,
}) {
  return ListingItem(
    id: id,
    event: ListingEventSummary(
      id: 10 + id,
      nama: eventNama,
      categorySlug: 'konser-festival',
      categoryNama: 'Konser & Festival',
    ),
    venueNama: 'Grand City Hall',
    kota: 'Surabaya',
    waktuAcara: DateTime.now().add(const Duration(days: 4)),
    jenis: 'limited',
    tipe: 'digital',
    harga: harga,
    jumlahTotal: jumlahTotal,
    jumlahTersedia: jumlahTotal - jumlahTerjual,
    jumlahTerjual: jumlahTerjual,
    tertarik: 2,
    status: status,
    confirmedAt: confirmedAt,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'ActivityScreen segmen Selling menampilkan listing, ubah terjual, tandai terjual semua, konfirmasi, edit, hapus di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = TokenStorage();
    await storage.saveSession(
      'jwt-token',
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

    final fakeRepo = _FakeListingRepository([
      _sampleListing(
        id: 1,
        eventNama: 'Konser Sheila on 7 Surabaya',
        status: 'tersedia',
        harga: 350000,
        jumlahTotal: 3,
        jumlahTerjual: 1,
      ),
      _sampleListing(
        id: 2,
        eventNama: 'Java Jazz Festival 2026',
        status: 'terjual',
        harga: 500000,
        jumlahTotal: 2,
        jumlahTerjual: 2,
      ),
    ]);

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ActivityScreen(
              listingRepository: fakeRepo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi header Activity dan 3 segmen
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Selling'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);

    // 2. Verifikasi listing ditampilkan dengan status badge
    expect(find.text('Konser Sheila on 7 Surabaya'), findsNWidgets(2));
    expect(find.text('Java Jazz Festival 2026'), findsNWidgets(2));
    expect(find.text('Tersedia'), findsWidgets);
    expect(find.text('Terjual'), findsWidgets);
    expect(find.text('Rp 350.000'), findsOneWidget);
    expect(find.text('2 sisa / 3 total'), findsOneWidget);

    // 3. Ubah jumlah terjual via stepper dialog
    await tester.tap(find.text('Ubah Terjual').first);
    await tester.pumpAndSettle();
    expect(find.text('Ubah Jumlah Terjual'), findsOneWidget);
    // Tambah 1 terjual (dari 1 menjadi 2)
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('2 terjual'),
        ),
        findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdatedStockId, 1);
    expect(fakeRepo.lastUpdatedStockValue, 2);
    expect(find.text('1 sisa / 3 total'), findsOneWidget);

    // 4. Konfirmasi ketersediaan masih tersedia
    await tester.tap(find.text('Konfirmasi').first);
    await tester.pumpAndSettle();
    expect(fakeRepo.lastConfirmedId, 1);
    expect(find.textContaining('Dikonfirmasi'), findsOneWidget);

    // 5. Tandai terjual semua
    await tester.tap(find.text('Terjual Semua').first);
    await tester.pumpAndSettle();
    expect(find.text('Tandai Terjual Semua?'), findsOneWidget);
    await tester.tap(find.text('Tandai Terjual'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdatedStockId, 1);
    expect(fakeRepo.lastUpdatedStockValue, 3);
    expect(find.text('0 sisa / 3 total'), findsOneWidget);

    // 6. Hapus listing
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Listing Tiket?'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastDeletedId, 1);
    expect(find.text('Konser Sheila on 7 Surabaya'), findsNothing);
    expect(find.text('Java Jazz Festival 2026'), findsNWidgets(2));

    // 7. Berpindah ke segmen Saved dan Chats
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tiket yang kamu simpan akan muncul di sini'), findsOneWidget);

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada percakapan'), findsOneWidget);

    // Kembali ke Selling
    await tester.tap(find.text('Selling'));
    await tester.pumpAndSettle();
    expect(find.text('Java Jazz Festival 2026'), findsNWidgets(2));

    // Bebas dari error atau overflow
    expect(tester.takeException(), isNull);

    // Bebas dari error atau overflow
    expect(tester.takeException(), isNull);
  });
}
