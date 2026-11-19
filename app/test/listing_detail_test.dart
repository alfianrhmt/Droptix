import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/countdown_timer.dart';
import 'package:droptix/core/widgets/event_poster.dart';
import 'package:droptix/core/widgets/stats_card.dart';
import 'package:droptix/features/chat/chat_screen.dart';
import 'package:droptix/features/events/event_models.dart';
import 'package:droptix/features/listings/listing_detail_screen.dart';
import 'package:droptix/features/listings/listing_models.dart';
import 'package:droptix/features/listings/listing_repository.dart';
import 'package:droptix/features/moderation/moderation_repository.dart';

class _FakeModerationRepository extends ModerationRepository {
  _FakeModerationRepository() : super(ApiClient(tokenStorage: TokenStorage()));

  @override
  Future<int> report({
    required String targetType,
    required int targetId,
    required String alasan,
    String? keterangan,
  }) async {
    return 101;
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(super.client, {this.currentUser});

  UserModel? currentUser;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final u = currentUser ??
        const UserModel(
          id: 1,
          nama: 'Budi Pembeli',
          email: 'budi@test.com',
          noWa: '6281234567890',
          kota: 'Surabaya',
        );
    return AuthResult(token: 'test-token', user: u);
  }

  @override
  Future<UserModel> getMe() async {
    return currentUser ??
        const UserModel(
          id: 1,
          nama: 'Budi Pembeli',
          email: 'budi@test.com',
          noWa: '6281234567890',
          kota: 'Surabaya',
        );
  }
}

class _FakeListingDetailRepository implements ListingRepository {
  _FakeListingDetailRepository({required this.detailItem});

  ListingItem detailItem;
  bool toggleFavoriteCalled = false;
  int? toggledId;
  bool? toggledCurrentStatus;

  @override
  Future<ListingItem> getListingDetail(int id, {double? lat, double? lng}) async {
    return detailItem;
  }

  @override
  Future<bool> toggleFavorite(int id, bool currentStatus) async {
    toggleFavoriteCalled = true;
    toggledId = id;
    toggledCurrentStatus = currentStatus;
    detailItem = detailItem.copyWith();
    return !currentStatus;
  }

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
  }) async =>
      PaginatedListings(items: [detailItem], total: 1, page: 1, limit: 20);

  @override
  Future<List<ListingItem>> getMyListings({String? status, int page = 1, int limit = 20}) async =>
      [detailItem];

  @override
  Future<PaginatedListings> getMyFavorites({double? lat, double? lng, int page = 1, int limit = 20}) async =>
      PaginatedListings(items: [detailItem], total: 1, page: 1, limit: 20);

  @override
  Future<ListingItem> createListing(Map<String, dynamic> payload) => throw UnimplementedError();

  @override
  Future<ListingItem> updateListing(int id, Map<String, dynamic> payload) => throw UnimplementedError();

  @override
  Future<ListingItem> updateStock(int id, int jumlahTerjual) => throw UnimplementedError();

  @override
  Future<DateTime> confirmListing(int id) => throw UnimplementedError();

  @override
  Future<void> deleteListing(int id) => throw UnimplementedError();

  @override
  Future<String> uploadTicketPhoto(dynamic bytes, {String filename = 'ticket.png'}) =>
      throw UnimplementedError();
}

ListingItem _createTestListing({
  int id = 101,
  String status = 'tersedia',
  String tipe = 'digital',
  bool isFavorite = false,
  int sellerId = 5,
  String sellerNama = 'Rina Penjual',
  int harga = 450000,
  int? hargaAsli = 600000,
  int? diskonPersen = 25,
  int jumlahTersedia = 2,
  int jumlahTerjual = 1,
  int tertarik = 7,
  String? seksi = 'CAT 2',
  String? noKursi = 'B12',
  String terikatNama = 'tidak',
  List<String> serahTerima = const ['transfer_eticket'],
  String? catatan = 'Bisa nego tipis, dijual karena ada tugas mendadak.',
  List<ListingPhotoItem> photos = const [
    ListingPhotoItem(id: 1, url: '/uploads/ticket_photo1.jpg'),
  ],
}) {
  return ListingItem(
    id: id,
    event: const ListingEventSummary(
      id: 7,
      nama: 'Soundrenaline 2026',
      posterUrl: '/uploads/soundrenaline.jpg',
      categorySlug: 'konser-festival',
      categoryNama: 'Konser & Festival',
    ),
    venueNama: 'Grand City Convention Hall',
    kota: 'Surabaya',
    waktuAcara: DateTime.now().add(const Duration(days: 3)),
    jenis: 'last_minute',
    tipe: tipe,
    seksi: seksi,
    noKursi: noKursi,
    harga: harga,
    hargaAsli: hargaAsli,
    diskonPersen: diskonPersen,
    jumlahTersedia: jumlahTersedia,
    jumlahTerjual: jumlahTerjual,
    tertarik: tertarik,
    status: status,
    jarakKm: 2.5,
    diperbarui: DateTime.now().subtract(const Duration(hours: 2)),
    confirmedAt: DateTime.now().subtract(const Duration(hours: 2)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isFavorite: isFavorite,
    satuan: true,
    terikatNama: terikatNama,
    serahTerima: serahTerima,
    lokasiPenjualKota: tipe == 'fisik' ? 'Surabaya Timur' : null,
    catatan: catatan,
    photos: photos,
    venue: const VenueItem(
      id: 3,
      nama: 'Grand City Convention Hall',
      kota: 'Surabaya',
      alamat: 'Jl. Walikota Mustajab No. 1, Genteng',
      lat: -7.26,
      lng: 112.75,
    ),
    seller: ListingSellerInfo(
      id: sellerId,
      nama: sellerNama,
      bergabung: DateTime(2026, 9, 1),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> createTestWidget({
    required ListingItem listing,
    required _FakeListingDetailRepository repository,
    UserModel? loggedInUser,
    ModerationRepository? moderationRepository,
  }) async {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authRepo = _FakeAuthRepository(apiClient, currentUser: loggedInUser);
    final authController = AuthController(
      repository: authRepo,
      tokenStorage: tokenStorage,
    );

    if (loggedInUser != null) {
      await tokenStorage.saveSession('mock-token', loggedInUser);
      await authController.restoreSession();
    } else {
      await tokenStorage.clear();
      authController.handleForcedLogout();
    }

    return AuthScope(
      controller: authController,
      child: CountdownTimerProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 740)),
            child: ListingDetailScreen(
              listingId: listing.id,
              initialItem: listing,
              listingRepository: repository,
              moderationRepository: moderationRepository ?? _FakeModerationRepository(),
            ),
          ),
        ),
      ),
    );
  }

  group('T5.2 ListingDetailScreen Tests', () {
    testWidgets('menampilkan 13 bagian DESIGN.md Bagian 7 secara lengkap dan rapi', (tester) async {
      final listing = _createTestListing();
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
        loggedInUser: const UserModel(id: 1, nama: 'Budi Pembeli', email: 'budi@test.com'),
      ));
      await tester.pumpAndSettle();

      // 1. Bar atas: icon back dan popup menu titik tiga
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // 2. Poster event
      expect(find.byType(EventPoster), findsOneWidget);

      // 3. Judul event huruf kapital di tengah
      expect(find.text('SOUNDRENALINE 2026'), findsOneWidget);

      // 4. Baris tanggal/countdown dan baris venue
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
      expect(find.textContaining('Grand City Convention Hall, Surabaya'), findsOneWidget);

      // 5. Baris aksi: Favorit dan Bagikan
      expect(find.byKey(const Key('listing_favorite_button')), findsOneWidget);
      expect(find.byKey(const Key('listing_share_button')), findsOneWidget);
      expect(find.text('Favorit'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);

      // 6. StatsCard: Tersedia / Terjual / Tertarik
      expect(find.byType(StatsCard), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);
      expect(find.text('Terjual'), findsOneWidget);
      expect(find.text('Tertarik'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // jumlah tersedia
      expect(find.text('1'), findsWidgets); // jumlah terjual
      expect(find.text('7'), findsWidgets); // tertarik

      // 7. Detail tiket (seksi, tipe, harga, diskon, jumlah, satuan, terikat nama, serah terima)
      expect(find.text('Detail Tiket'), findsOneWidget);
      expect(find.textContaining('CAT 2 (Kursi: B12)'), findsOneWidget);
      expect(find.text('Digital (E-Ticket)'), findsOneWidget);
      expect(find.text('Rp 450.000'), findsOneWidget);
      expect(find.text('Rp 600.000'), findsOneWidget); // harga asli
      expect(find.text('-25%'), findsOneWidget); // diskon persen
      expect(find.textContaining('2 tiket tersedia (dari total 3)'), findsOneWidget);
      expect(find.text('Bisa dibeli satuan'), findsOneWidget);
      expect(find.text('Tidak (bebas pindah tangan)'), findsOneWidget);
      expect(find.text('Transfer E-Ticket'), findsOneWidget);

      // 8. Lokasi
      expect(find.text('Lokasi & Jarak'), findsOneWidget);
      expect(find.text('Jl. Walikota Mustajab No. 1, Genteng'), findsOneWidget);
      expect(find.text('2.5 km dari lokasimu'), findsOneWidget);

      // 9. Catatan penjual
      expect(find.text('Catatan Penjual'), findsOneWidget);
      expect(find.textContaining('Bisa nego tipis'), findsOneWidget);

      // 10. Foto tiket penjual dan peringatan QR
      expect(find.text('Foto Tiket dari Penjual'), findsOneWidget);
      expect(find.textContaining('Peringatan: Penjual wajib menyamarkan QR/barcode'), findsOneWidget);

      // 11. Penjual: nama, bergabung sejak, diperbarui ... lalu
      expect(find.text('Penjual'), findsOneWidget);
      expect(find.text('Rina Penjual'), findsOneWidget);
      expect(find.textContaining('Bergabung sejak September 2026'), findsOneWidget);
      expect(find.textContaining('Diperbarui'), findsOneWidget);

      // 12. Banner disclaimer kecil
      expect(find.textContaining('Droptix tidak menyediakan rekening bersama'), findsOneWidget);

      // 13. Tombol tetap di bawah: "Chat dengan penjual"
      expect(find.byKey(const Key('listing_chat_button')), findsOneWidget);
      expect(find.text('Chat dengan penjual'), findsOneWidget);
    });

    testWidgets('FR-5: email dan nomor WhatsApp TIDAK PERNAH muncul di layar detail', (tester) async {
      final listing = _createTestListing();
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // Pastikan string nomor whatsapp dan email tidak ada sama sekali di widget tree
      expect(find.textContaining('628'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('whatsapp', skipOffstage: false), findsNothing);
      expect(find.textContaining('wa.me', skipOffstage: false), findsNothing);
    });

    testWidgets('dapat toggle status favorit dan menampilkan snackbar feedback', (tester) async {
      final listing = _createTestListing(isFavorite: false);
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
        loggedInUser: const UserModel(id: 1, nama: 'Budi Pembeli', email: 'budi@test.com'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Favorit'), findsOneWidget);

      // Ketuk tombol Favorit
      await tester.tap(find.byKey(const Key('listing_favorite_button')));
      await tester.pumpAndSettle();

      expect(repo.toggleFavoriteCalled, isTrue);
      expect(repo.toggledId, 101);
      expect(repo.toggledCurrentStatus, isFalse);

      // Feedback snackbar tampil dan status tombol berubah menjadi 'Tersimpan'
      expect(find.text('Listing ditambahkan ke favorit'), findsOneWidget);
      expect(find.text('Tersimpan'), findsOneWidget);
    });

    testWidgets('tombol Bagikan menyalin tautan ke papan klip dan menampilkan SnackBar', (tester) async {
      final listing = _createTestListing();
      final repo = _FakeListingDetailRepository(detailItem: listing);

      // Mock Clipboard handler
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // Ketuk tombol Bagikan
      await tester.tap(find.byKey(const Key('listing_share_button')));
      await tester.pumpAndSettle();

      expect(copiedText, 'Lihat tiket Soundrenaline 2026 di Droptix: https://droptix.app/listings/101');
      expect(find.text('Tautan listing berhasil disalin ke papan klip!'), findsOneWidget);
    });

    testWidgets('menu titik tiga menampilkan dialog Laporkan Listing', (tester) async {
      final listing = _createTestListing();
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // Buka popup menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Laporkan listing'), findsOneWidget);

      // Pilih Laporkan listing
      await tester.tap(find.text('Laporkan listing'));
      await tester.pumpAndSettle();

      // Dialog pelaporan muncul dengan opsi alasan
      expect(find.text('Laporkan Listing'), findsOneWidget);
      expect(find.text('Tiket palsu atau tidak valid'), findsOneWidget);

      // Pilih salah satu opsi
      await tester.tap(find.text('Tiket palsu atau tidak valid'));
      await tester.pumpAndSettle();

      // Tekan tombol Kirim Laporan
      await tester.tap(find.byKey(const Key('report_submit_button')));
      await tester.pumpAndSettle();

      // SnackBar konfirmasi laporan diterima
      expect(find.text('Laporan Anda telah diterima dan akan ditinjau tim Droptix.'), findsOneWidget);
    });

    testWidgets('listing berstatus terjual menampilkan alert dan menonaktifkan tombol chat', (tester) async {
      final listing = _createTestListing(status: 'terjual', jumlahTersedia: 0, jumlahTerjual: 2);
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // Alert status terjual tampil
      expect(find.text('Tiket ini telah terjual habis.'), findsOneWidget);

      // Tombol chat di bawah dinonaktifkan
      final chatBtnFinder = find.byKey(const Key('listing_chat_button'));
      expect(chatBtnFinder, findsOneWidget);
      expect(find.text('Tiket Tidak Tersedia'), findsOneWidget);
      expect(find.text('Tiket telah terjual habis.'), findsOneWidget);

      // Tombol tidak memiliki callback onPressed (disabled)
      final elevatedButton = tester.widget<ElevatedButton>(
        find.descendant(of: chatBtnFinder, matching: find.byType(ElevatedButton)),
      );
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('listing milik sendiri menonaktifkan tombol chat dengan pesan yang sesuai', (tester) async {
      // Penjual ID 5, user yang sedang login ID 5
      final listing = _createTestListing(sellerId: 5);
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
        loggedInUser: const UserModel(id: 5, nama: 'Rina Penjual', email: 'rina@test.com'),
      ));
      await tester.pumpAndSettle();

      // Tombol chat dinonaktifkan
      final chatBtnFinder = find.byKey(const Key('listing_chat_button'));
      expect(chatBtnFinder, findsOneWidget);
      expect(find.text('Listing Milik Sendiri'), findsOneWidget);
      expect(find.text('Kamu adalah penjual tiket ini.'), findsOneWidget);

      final elevatedButton = tester.widget<ElevatedButton>(
        find.descendant(of: chatBtnFinder, matching: find.byType(ElevatedButton)),
      );
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('tombol Chat dengan penjual membuka ChatScreen', (tester) async {
      final listing = _createTestListing();
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
        loggedInUser: const UserModel(id: 1, nama: 'Budi Pembeli', email: 'budi@test.com'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Chat dengan penjual'), findsOneWidget);

      await tester.tap(find.byKey(const Key('listing_chat_button')));
      await tester.pumpAndSettle();

      // Terbuka layar ChatScreen
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Rina Penjual'), findsWidgets);
    });

    testWidgets('tiket fisik menampilkan area penjual pada bagian lokasi (bukan venue acara)', (tester) async {
      final listing = _createTestListing(tipe: 'fisik');
      final repo = _FakeListingDetailRepository(detailItem: listing);

      await tester.pumpWidget(await createTestWidget(
        listing: listing,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Area Penjual'), findsOneWidget);
      expect(find.text('Surabaya Timur'), findsOneWidget);
      // Untuk tiket fisik, label "Venue Acara" tidak ditampilkan di box lokasi
      expect(find.text('Venue Acara'), findsNothing);
    });
  });
}
