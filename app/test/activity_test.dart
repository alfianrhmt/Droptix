import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/features/activity/activity_screen.dart';
import 'package:droptix/features/chat/chat_models.dart';
import 'package:droptix/features/chat/chat_repository.dart';
import 'package:droptix/features/listings/listing_detail_screen.dart';
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
  _FakeListingRepository(
    List<ListingItem> initialListings, {
    List<ListingItem> initialSavedListings = const [],
  })  : listings = List.of(initialListings),
        savedListings = List.of(initialSavedListings);

  final List<ListingItem> listings;
  final List<ListingItem> savedListings;
  int? lastConfirmedId;
  int? lastDeletedId;
  int? lastUpdatedStockId;
  int? lastUpdatedStockValue;
  int? lastToggledFavoriteId;

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
  Future<ListingItem> getListingDetail(int id, {double? lat, double? lng}) async {
    return savedListings.firstWhere(
      (l) => l.id == id,
      orElse: () => listings.firstWhere((l) => l.id == id),
    );
  }

  @override
  Future<String> uploadTicketPhoto(dynamic bytes, {String filename = 'ticket.png'}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> toggleFavorite(int id, bool currentStatus) async {
    lastToggledFavoriteId = id;
    if (currentStatus) {
      savedListings.removeWhere((l) => l.id == id);
      return false;
    } else {
      final item = listings.firstWhere(
        (l) => l.id == id,
        orElse: () => _sampleListing(
          id: id,
          eventNama: 'Sample Event',
          status: 'tersedia',
          harga: 100000,
          jumlahTotal: 1,
          jumlahTerjual: 0,
        ),
      );
      savedListings.add(item);
      return true;
    }
  }

  @override
  Future<PaginatedListings> getMyFavorites({double? lat, double? lng, int page = 1, int limit = 20}) async =>
      PaginatedListings(
        items: List.of(savedListings),
        total: savedListings.length,
        page: page,
        limit: limit,
      );
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({List<ConversationModel>? initialConversations})
      : conversations = List.of(initialConversations ?? []);

  final List<ConversationModel> conversations;

  @override
  ApiClient get client => ApiClient(tokenStorage: TokenStorage());

  @override
  Future<List<ConversationModel>> getConversations({int page = 1, int limit = 20}) async {
    return conversations;
  }

  @override
  Future<ConversationModel?> getConversationForListing(int listingId) async {
    return conversations.cast<ConversationModel?>().firstWhere(
          (c) => c?.listing.id == listingId,
          orElse: () => null,
        );
  }

  @override
  Future<ConversationModel> getConversation(int conversationId) async {
    return conversations.firstWhere((c) => c.id == conversationId);
  }

  @override
  Future<({List<ChatMessageModel> messages, bool adaLebihLama})> getMessages(
    int conversationId, {
    int? before,
    int limit = 30,
  }) async {
    return (messages: <ChatMessageModel>[], adaLebihLama: false);
  }

  @override
  Future<ChatMessageModel> sendMessage(int conversationId, String isi) async {
    return ChatMessageModel(
      id: 1,
      conversationId: conversationId,
      senderId: 1,
      isi: isi,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<({ConversationModel conversation, ChatMessageModel message})>
      startListingConversation(int listingId, String isi) async {
    throw UnimplementedError();
  }

  @override
  Future<({int belumDibaca, int chatsBelumDibaca})> markAsRead(int conversationId) async {
    return (belumDibaca: 0, chatsBelumDibaca: 0);
  }

  @override
  Future<int> getUnreadChatsCount() async {
    return 0;
  }

  @override
  Future<String> getWhatsAppUrl(int conversationId) async {
    return 'https://wa.me/6281234567890';
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
  bool isFavorite = false,
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
    isFavorite: isFavorite,
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
              chatRepository: _FakeChatRepository(),
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
  });

  testWidgets('ActivityScreen segmen Saved menampilkan listing favorit, status badge, un-favorite dengan undo, dan buka detail', (tester) async {
    final storage = TokenStorage();
    await storage.saveSession(
      'token-saved-test',
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

    final savedItems = [
      _sampleListing(
        id: 101,
        eventNama: 'Konser Sheila on 7 Surabaya',
        status: 'tersedia',
        harga: 350000,
        jumlahTotal: 3,
        jumlahTerjual: 1,
        isFavorite: true,
      ),
      _sampleListing(
        id: 102,
        eventNama: 'Synchronize Festival 2026',
        status: 'terjual',
        harga: 450000,
        jumlahTotal: 2,
        jumlahTerjual: 2,
        isFavorite: true,
      ),
      _sampleListing(
        id: 103,
        eventNama: 'Pameran Seni Kontemporer',
        status: 'kedaluwarsa',
        harga: 120000,
        jumlahTotal: 1,
        jumlahTerjual: 0,
        isFavorite: true,
      ),
    ];

    final fakeRepo = _FakeListingRepository([], initialSavedListings: savedItems);

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 740)),
            child: Scaffold(
              body: ActivityScreen(
                initialSegment: ActivitySegment.saved,
                listingRepository: fakeRepo,
                chatRepository: _FakeChatRepository(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi ketiga item tampil
    expect(find.text('Konser Sheila on 7 Surabaya'), findsOneWidget);
    expect(find.text('Synchronize Festival 2026'), findsOneWidget);
    expect(find.text('Pameran Seni Kontemporer'), findsOneWidget);

    // 2. Verifikasi status badge muncul pada masing-masing item
    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Terjual'), findsOneWidget);
    expect(find.text('Kedaluwarsa'), findsOneWidget);

    // 3. Menghapus favorit dengan mengetuk ikon bookmark
    final bookmarkIcons = find.byIcon(Icons.bookmark_rounded);
    expect(bookmarkIcons, findsNWidgets(3));

    await tester.tap(bookmarkIcons.first);
    await tester.pumpAndSettle();

    expect(fakeRepo.lastToggledFavoriteId, 101);
    expect(find.text('Konser Sheila on 7 Surabaya'), findsNothing);
    expect(find.text('Dihapus dari favorit'), findsOneWidget);
    expect(find.text('Urungkan'), findsOneWidget);

    // 4. Mengurungkan penghapusan favorit
    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();

    expect(find.text('Konser Sheila on 7 Surabaya'), findsOneWidget);

    // 5. Mengetuk listing berstatus terjual tetap bisa membuka ListingDetailScreen
    await tester.tap(find.text('Synchronize Festival 2026'));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailScreen), findsOneWidget);
    expect(find.text('SYNCHRONIZE FESTIVAL 2026'), findsOneWidget);
    expect(find.text('Tiket Tidak Tersedia'), findsOneWidget);

    // Kembali ke Activity
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Segmen Saved menampilkan EmptyState jika kosong dan tombol Cari Tiket berpindah ke Home', (tester) async {
    final storage = TokenStorage();
    await storage.saveSession(
      'token-empty-test',
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

    final fakeRepo = _FakeListingRepository([], initialSavedListings: []);
    bool homeNavigated = false;

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 740)),
            child: Scaffold(
              body: ActivityScreen(
                initialSegment: ActivitySegment.saved,
                listingRepository: fakeRepo,
                onNavigateToHome: () => homeNavigated = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi EmptyState
    expect(find.textContaining('Tiket yang kamu simpan akan muncul di sini'), findsOneWidget);
    expect(find.text('Cari Tiket'), findsOneWidget);

    // Ketuk tombol Cari Tiket
    await tester.tap(find.text('Cari Tiket'));
    await tester.pumpAndSettle();

    expect(homeNavigated, isTrue);
    expect(tester.takeException(), isNull);
  });
}
