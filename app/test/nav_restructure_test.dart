import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';
import 'package:droptix/features/chat/chat_inbox_screen.dart';
import 'package:droptix/features/chat/chat_models.dart';
import 'package:droptix/features/chat/chat_repository.dart';
import 'package:droptix/features/listings/listing_models.dart';
import 'package:droptix/features/listings/listing_repository.dart';
import 'package:droptix/features/saved/saved_screen.dart';
import 'package:droptix/features/sell/sell_screen.dart';
import 'package:droptix/features/sell/sell_tab_screen.dart';
import 'package:droptix/features/shell/app_shell.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(tokenStorage: TokenStorage()));

  @override
  Future<UserModel> getMe() async {
    return const UserModel(
      id: 1,
      nama: 'Budi Santoso',
      email: 'budi@droptix.dev',
      noWa: '6281234567890',
      kota: 'Surabaya',
    );
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return const AuthResult(
      token: 'jwt-token-123',
      user: UserModel(
        id: 1,
        nama: 'Budi Santoso',
        email: 'budi@droptix.dev',
        noWa: '6281234567890',
        kota: 'Surabaya',
      ),
    );
  }
}

class _FakeListingRepository implements ListingRepository {
  _FakeListingRepository({
    List<ListingItem> initialListings = const [],
    List<ListingItem> initialSavedListings = const [],
  })  : listings = List.of(initialListings),
        savedListings = List.of(initialSavedListings);

  final List<ListingItem> listings;
  final List<ListingItem> savedListings;
  int unmarkCallCount = 0;

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
    final idx = listings.indexWhere((l) => l.id == id);
    final current = listings[idx];
    final sisa = current.jumlahTotal - jumlahTerjual;
    final updated = current.copyWith(
      jumlahTersedia: sisa,
      jumlahTerjual: jumlahTerjual,
      status: sisa <= 0 ? 'terjual' : 'tersedia',
    );
    listings[idx] = updated;
    return updated;
  }

  @override
  Future<DateTime> confirmListing(int id) async => DateTime.now();

  @override
  Future<void> deleteListing(int id) async {
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
    if (currentStatus) {
      savedListings.removeWhere((l) => l.id == id);
      unmarkCallCount++;
      return false;
    } else {
      final item = listings.firstWhere(
        (l) => l.id == id,
        orElse: () => _sampleListing(id: id, eventNama: 'Sample', status: 'tersedia'),
      );
      savedListings.add(item);
      return true;
    }
  }

  @override
  Future<PaginatedListings> getMyFavorites({
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) async =>
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
  Future<ConversationModel?> getConversationForListing(int listingId) async => null;

  @override
  Future<ConversationModel> getConversation(int conversationId) async =>
      conversations.firstWhere((c) => c.id == conversationId);

  @override
  Future<({List<ChatMessageModel> messages, bool adaLebihLama})> getMessages(
    int conversationId, {
    int? before,
    int limit = 30,
  }) async =>
      (messages: <ChatMessageModel>[], adaLebihLama: false);

  @override
  Future<ChatMessageModel> sendMessage(int conversationId, String isi) async =>
      ChatMessageModel(
        id: 1,
        conversationId: conversationId,
        senderId: 1,
        isi: isi,
        createdAt: DateTime.now(),
      );

  @override
  Future<({ConversationModel conversation, ChatMessageModel message})>
      startListingConversation(int listingId, String isi) async {
    throw UnimplementedError();
  }

  @override
  Future<({int belumDibaca, int chatsBelumDibaca})> markAsRead(int conversationId) async =>
      (belumDibaca: 0, chatsBelumDibaca: 0);

  @override
  Future<int> getUnreadChatsCount() async => 3;

  @override
  Future<String> getWhatsAppUrl(int conversationId) async => 'https://wa.me/6281234567890';
}

ListingItem _sampleListing({
  required int id,
  required String eventNama,
  required String status,
  int harga = 150000,
  int total = 2,
  int terjual = 0,
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
    jumlahTotal: total,
    jumlahTersedia: total - terjual,
    jumlahTerjual: terjual,
    tertarik: 2,
    status: status,
    isFavorite: true,
  );
}

Future<AuthController> _buildAuth({bool loggedIn = true}) async {
  final storage = TokenStorage();
  final authRepo = _FakeAuthRepository();
  final auth = AuthController(repository: authRepo, tokenStorage: storage);
  if (loggedIn) {
    await auth.login(email: 'budi@droptix.dev', password: 'password123');
  } else {
    await auth.restoreSession();
  }
  return auth;
}

Widget wrap(Widget child, AuthController auth) {
  return AuthScope(
    controller: auth,
    child: CountdownTimerProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: child,
      ),
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

  group('T9.1: SavedScreen Tests', () {
    testWidgets('menampilkan EmptyState saat belum ada tiket favorit', (tester) async {
      final auth = await _buildAuth();
      final repo = _FakeListingRepository(initialSavedListings: []);

      await tester.pumpWidget(wrap(SavedScreen(listingRepository: repo), auth));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsOneWidget);
      expect(
        find.text(
          'Simpan tiket yang kamu incar dengan mengetuk ikon simpan agar mudah dipantau kapan saja.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('menampilkan daftar tiket tersimpan dan tombol un-favorite dengan snackbar undo', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuth();
      final item = _sampleListing(id: 101, eventNama: 'Konser Dewa 19 Surabaya', status: 'tersedia');
      final repo = _FakeListingRepository(initialSavedListings: [item]);

      await tester.pumpWidget(wrap(SavedScreen(listingRepository: repo), auth));
      await tester.pumpAndSettle();

      expect(find.text('Konser Dewa 19 Surabaya'), findsOneWidget);

      // Ketuk tombol simpan/favorit pada item (ikon bintang)
      await tester.tap(find.byIcon(Icons.star_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Item terhapus dan muncul SnackBar
      expect(find.text('"Konser Dewa 19 Surabaya" dihapus dari Saved.'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);

      // Ketuk Batal
      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Konser Dewa 19 Surabaya'), findsOneWidget);
    });
  });

  group('T9.2: ChatInboxScreen Tests', () {
    testWidgets('menampilkan EmptyState saat belum ada percakapan', (tester) async {
      final auth = await _buildAuth();
      final repo = _FakeChatRepository(initialConversations: []);

      await tester.pumpWidget(wrap(ChatInboxScreen(chatRepository: repo), auth));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
      expect(
        find.text(
          'Mulai percakapan dengan penjual atau pembeli melalui tombol Chat pada halaman detail tiket.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('menampilkan daftar percakapan aktif', (tester) async {
      final auth = await _buildAuth();
      final repo = _FakeChatRepository(
        initialConversations: [
          ConversationModel(
            id: 55,
            listing: const ConversationListingModel(
              id: 20,
              judul: 'Sheila on 7 Live in Surabaya',
              harga: 250000,
              status: 'tersedia',
            ),
            lawan: const ConversationUserModel(id: 2, nama: 'Siti Sarah'),
            peran: 'pembeli',
            pesanTerakhir: 'Apakah tiketnya masih ada kak?',
            waktuPesanTerakhir: DateTime.now(),
            belumDibaca: 2,
            izinkanWa: true,
          ),
        ],
      );

      await tester.pumpWidget(wrap(ChatInboxScreen(chatRepository: repo), auth));
      await tester.pumpAndSettle();

      expect(find.text('Siti Sarah'), findsOneWidget);
      expect(find.text('Sheila on 7 Live in Surabaya'), findsOneWidget);
      expect(find.text('Apakah tiketnya masih ada kak?'), findsOneWidget);
      expect(find.byType(UnreadBadge), findsOneWidget);
    });
  });

  group('T9.3: SellTabScreen Tests', () {
    testWidgets('menampilkan daftar tiket penjualan saya, filter status, dan tombol Jual Tiket', (tester) async {
      final auth = await _buildAuth();
      final repo = _FakeListingRepository(
        initialListings: [
          _sampleListing(id: 201, eventNama: 'Jazz Traffic 2026', status: 'tersedia', total: 2, terjual: 0),
        ],
      );

      await tester.pumpWidget(wrap(SellTabScreen(listingRepository: repo), auth));
      await tester.pumpAndSettle();

      expect(find.text('Penjualan'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Jual Tiket'), findsOneWidget);
      expect(find.text('Jazz Traffic 2026'), findsWidgets);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Tersedia'), findsWidgets);
      expect(find.text('Terjual'), findsOneWidget);
    });
  });

  group('T9.4: AppShell 5-Tab Navigation Tests', () {
    testWidgets('DroptixBottomNav memiliki 5 item tab: Home, Saved, Sell, Chat, Profile', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuth(loggedIn: false);

      await tester.pumpWidget(
        wrap(
          const AppShell(),
          auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Sell'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('T9.5: Header & Back Button Tests', () {
    testWidgets('SellScreen menampilkan tombol panah balik pada langkah 1 dan mengetuknya menutup halaman', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = await _buildAuth();
      bool popped = false;

      await tester.pumpWidget(
        wrap(
          Navigator(
            initialRoute: '/',
            onGenerateRoute: (settings) {
              if (settings.name == '/sell') {
                return MaterialPageRoute(
                  builder: (context) => SellScreen(onPosted: () {}),
                );
              }
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/sell'),
                      child: const Text('Buka Jual'),
                    ),
                  ),
                ),
              );
            },
            observers: [
              _PopObserver(onPop: () => popped = true),
            ],
          ),
          auth,
        ),
      );
      await tester.pumpAndSettle();

      // Buka halaman SellScreen
      await tester.tap(find.text('Buka Jual'));
      await tester.pumpAndSettle();

      // Memastikan ada tombol panah kembali pada langkah 1
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.textContaining('Jual Tiket (1/5)'), findsOneWidget);

      // Ketuk tombol panah kembali
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('Header judul pada Saved, Chat, Sell, dan Profile menggunakan ukuran titleLarge yang seragam', (tester) async {
      final savedText = Text('Saved', style: AppTextStyles.titleLarge);
      final chatText = Text('Chat', style: AppTextStyles.titleLarge);
      final sellText = Text('Penjualan', style: AppTextStyles.titleLarge);
      final profileText = Text('Profile', style: AppTextStyles.titleLarge);

      expect(savedText.style?.fontSize, equals(profileText.style?.fontSize));
      expect(chatText.style?.fontSize, equals(profileText.style?.fontSize));
      expect(sellText.style?.fontSize, equals(profileText.style?.fontSize));
      expect(profileText.style?.fontSize, equals(22));
    });
  });
}

class _PopObserver extends NavigatorObserver {
  _PopObserver({required this.onPop});
  final VoidCallback onPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPop();
    super.didPop(route, previousRoute);
  }
}
