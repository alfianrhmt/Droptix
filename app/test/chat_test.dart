import 'dart:async';
import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/network/api_error.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/badges.dart';
import 'package:droptix/core/widgets/chat_widgets.dart';
import 'package:droptix/features/activity/activity_screen.dart';
import 'package:droptix/features/chat/chat_models.dart';
import 'package:droptix/features/chat/chat_repository.dart';
import 'package:droptix/features/chat/chat_screen.dart';
import 'package:droptix/features/chat/chat_socket_service.dart';
import 'package:droptix/features/listings/listing_models.dart';
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
      nama: 'Pembeli Satu',
      email: 'buyer@example.com',
      noWa: '6281234567890',
      kota: 'Surabaya',
    );
  }
}

class _TestChatRepository implements ChatRepository {
  _TestChatRepository({
    List<ConversationModel>? initialConversations,
    List<ChatMessageModel>? initialMessages,
  })  : conversations = List.of(initialConversations ?? []),
        messages = List.of(initialMessages ?? []);

  final List<ConversationModel> conversations;
  final List<ChatMessageModel> messages;
  int? markedReadConvId;
  String? lastSentMessageText;
  int? lastSentListingId;

  @override
  ApiClient get client => ApiClient(tokenStorage: TokenStorage());

  @override
  Future<ConversationModel?> getConversationForListing(int listingId) async {
    return conversations.cast<ConversationModel?>().firstWhere(
          (c) => c?.listing.id == listingId,
          orElse: () => null,
        );
  }

  @override
  Future<({ConversationModel conversation, ChatMessageModel message})>
      startListingConversation(int listingId, String isi) async {
    lastSentListingId = listingId;
    lastSentMessageText = isi;

    final conv = ConversationModel(
      id: 10,
      listing: const ConversationListingModel(
        id: 42,
        judul: 'Konser Sheila on 7 Surabaya',
        harga: 350000,
        status: 'tersedia',
      ),
      lawan: const ConversationUserModel(id: 2, nama: 'Penjual Dua'),
      peran: 'pembeli',
      pesanTerakhir: isi,
      waktuPesanTerakhir: DateTime.now(),
      belumDibaca: 0,
      izinkanWa: true,
    );

    final msg = ChatMessageModel(
      id: 101,
      conversationId: 10,
      senderId: 1,
      isi: isi,
      createdAt: DateTime.now(),
    );

    conversations.add(conv);
    messages.insert(0, msg);
    return (conversation: conv, message: msg);
  }

  @override
  Future<List<ConversationModel>> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    return conversations;
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
    final filtered = messages.where((m) => m.conversationId == conversationId).toList();
    return (messages: filtered, adaLebihLama: false);
  }

  @override
  Future<ChatMessageModel> sendMessage(int conversationId, String isi) async {
    lastSentMessageText = isi;
    final msg = ChatMessageModel(
      id: messages.length + 1,
      conversationId: conversationId,
      senderId: 1,
      isi: isi,
      createdAt: DateTime.now(),
    );
    messages.insert(0, msg);
    return msg;
  }

  @override
  Future<({int belumDibaca, int chatsBelumDibaca})> markAsRead(
    int conversationId,
  ) async {
    markedReadConvId = conversationId;
    return (belumDibaca: 0, chatsBelumDibaca: 0);
  }

  @override
  Future<int> getUnreadChatsCount() async {
    return conversations.where((c) => c.belumDibaca > 0).length;
  }

  int? requestedWaConvId;
  String? mockWaUrl = 'https://wa.me/6281234567890?text=Halo%20Droptix';
  bool throwOnWa = false;

  @override
  Future<String> getWhatsAppUrl(int conversationId) async {
    requestedWaConvId = conversationId;
    if (throwOnWa) {
      throw const ApiException(
        code: 'FORBIDDEN',
        message: 'Penjual tidak mengizinkan WhatsApp.',
        statusCode: 403,
      );
    }
    return mockWaUrl ?? '';
  }
}

class _TestSocketService extends ChatSocketService {
  _TestSocketService() : super();

  final StreamController<Map<String, dynamic>> _testMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onNewMessage => _testMessageController.stream;

  void emitTestMessage(Map<String, dynamic> data) {
    _testMessageController.add(data);
  }

  @override
  void dispose() {
    _testMessageController.close();
    super.dispose();
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> buildTestApp({
    required Widget child,
    AuthController? authController,
  }) async {
    final storage = TokenStorage();
    await storage.saveSession(
      'jwt-token',
      const UserModel(
        id: 1,
        nama: 'Pembeli Satu',
        email: 'buyer@example.com',
        noWa: '6281234567890',
        kota: 'Surabaya',
      ),
    );

    final auth = authController ??
        AuthController(
          repository: _FakeAuthRepository(),
          tokenStorage: storage,
        );
    await auth.restoreSession();

    return AuthScope(
      controller: auth,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 740)),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('T6.3: Flutter ChatScreen Tests', () {
    testWidgets('menampilkan ChatListingCard, chips saran cepat saat chat baru, dan mengirim pesan pertama', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _TestChatRepository();
      final listingItem = ListingItem(
        id: 42,
        event: const ListingEventSummary(
          id: 1,
          nama: 'Konser Sheila on 7 Surabaya',
          categorySlug: 'konser-festival',
          categoryNama: 'Konser & Festival',
        ),
        venueNama: 'Grand City',
        kota: 'Surabaya',
        waktuAcara: DateTime.now().add(const Duration(days: 3)),
        jenis: 'limited',
        tipe: 'digital',
        harga: 350000,
        jumlahTotal: 2,
        jumlahTersedia: 2,
        jumlahTerjual: 0,
        tertarik: 1,
        status: 'tersedia',
        seller: const ListingSellerInfo(
          id: 2,
          nama: 'Penjual Dua',
          bergabung: null,
        ),
      );

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            listingId: 42,
            listingDetail: listingItem,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi AppBar dan ChatListingCard
      expect(find.text('Penjual Dua'), findsOneWidget);
      expect(find.text('Konser Sheila on 7 Surabaya'), findsOneWidget);
      expect(find.text('Rp 350.000'), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);

      // Verifikasi chip saran cepat
      expect(find.text('Halo, masih tersedia?'), findsOneWidget);
      expect(find.text('Boleh nego?'), findsOneWidget);

      // Ketuk chip "Halo, masih tersedia?"
      await tester.tap(find.text('Halo, masih tersedia?'));
      await tester.pumpAndSettle();

      // Verifikasi pesan terkirim
      expect(repo.lastSentListingId, 42);
      expect(repo.lastSentMessageText, 'Halo, masih tersedia?');
      expect(find.text('Halo, masih tersedia?'), findsOneWidget);
    });

    testWidgets('menampilkan riwayat pesan yang ada, DateSeparator, dan mengirim balasan via ChatInput', (tester) async {
      final repo = _TestChatRepository(
        initialConversations: [
          ConversationModel(
            id: 12,
            listing: const ConversationListingModel(
              id: 42,
              judul: 'Konser Sheila on 7 Surabaya',
              harga: 350000,
              status: 'tersedia',
            ),
            lawan: const ConversationUserModel(id: 2, nama: 'Penjual Dua'),
            peran: 'pembeli',
            pesanTerakhir: 'Siap kak',
            waktuPesanTerakhir: DateTime.now(),
            belumDibaca: 0,
            izinkanWa: false,
          ),
        ],
        initialMessages: [
          ChatMessageModel(
            id: 1,
            conversationId: 12,
            senderId: 1,
            isi: 'Halo apakah tiket ready?',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          ChatMessageModel(
            id: 2,
            conversationId: 12,
            senderId: 2,
            isi: 'Ready kak!',
            createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        ],
      );

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 12,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi pesan lama
      expect(find.text('Halo apakah tiket ready?'), findsOneWidget);
      expect(find.text('Ready kak!'), findsOneWidget);
      expect(find.text('Hari ini'), findsOneWidget);

      // Ketik pesan di ChatInput
      await tester.enterText(find.byType(TextField), 'Bisa transfer sekarang?');
      await tester.pumpAndSettle();

      // Ketuk kirim
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(repo.lastSentMessageText, 'Bisa transfer sekarang?');
      expect(find.text('Bisa transfer sekarang?'), findsOneWidget);
    });

    testWidgets('menampilkan pesan masuk secara realtime via socket event message:new', (tester) async {
      final socketService = _TestSocketService();
      final repo = _TestChatRepository(
        initialConversations: [
          ConversationModel(
            id: 12,
            listing: const ConversationListingModel(
              id: 42,
              judul: 'Konser Sheila on 7 Surabaya',
              harga: 350000,
              status: 'tersedia',
            ),
            lawan: const ConversationUserModel(id: 2, nama: 'Penjual Dua'),
            peran: 'pembeli',
          ),
        ],
      );

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 12,
            chatRepository: repo,
            socketService: socketService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulasikan pesan masuk dari lawan bicara melalui soket
      socketService.emitTestMessage({
        'conversation': {'id': 12, 'belum_dibaca': 1},
        'message': {
          'id': 999,
          'conversation_id': 12,
          'sender_id': 2,
          'isi': 'Halo dari socket realtime!',
          'created_at': DateTime.now().toIso8601String(),
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Halo dari socket realtime!'), findsOneWidget);
    });
  });

  group('T6.3: ActivityScreen Segmen Chats Tests', () {
    testWidgets('menampilkan EmptyState ketika tidak ada percakapan', (tester) async {
      final repo = _TestChatRepository(initialConversations: []);

      await tester.pumpWidget(
        await buildTestApp(
          child: ActivityScreen(
            initialSegment: ActivitySegment.chats,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada percakapan.'), findsOneWidget);
    });

    testWidgets('menampilkan ConversationRow dengan unread badge dan membuka ChatScreen saat diketuk', (tester) async {
      final conv = ConversationModel(
        id: 15,
        listing: const ConversationListingModel(
          id: 42,
          judul: 'Konser Sheila on 7 Surabaya',
          harga: 350000,
          status: 'tersedia',
        ),
        lawan: const ConversationUserModel(id: 2, nama: 'Rina Penjual'),
        peran: 'pembeli',
        pesanTerakhir: 'Tiket masih tersedia kak',
        waktuPesanTerakhir: DateTime.now().subtract(const Duration(minutes: 10)),
        belumDibaca: 3,
      );

      final repo = _TestChatRepository(initialConversations: [conv]);

      await tester.pumpWidget(
        await buildTestApp(
          child: ActivityScreen(
            initialSegment: ActivitySegment.chats,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi ConversationRow
      expect(find.text('Rina Penjual'), findsOneWidget);
      expect(find.text('Konser Sheila on 7 Surabaya'), findsOneWidget);
      expect(find.text('Tiket masih tersedia kak'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Unread badge

      // Ketuk baris percakapan
      await tester.tap(find.text('Rina Penjual'));
      await tester.pumpAndSettle();

      // Membuka ChatScreen
      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });

  group('T6.3: DroptixBottomNav Unread Badge Tests', () {
    testWidgets('menampilkan UnreadBadge pada ikon Activity saat unreadCount > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            bottomNavigationBar: DroptixBottomNav(
              currentIndex: 0,
              onTap: (_) {},
              unreadCount: 4,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnreadBadge), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('menampilkan "9+" pada ikon Activity saat unreadCount > 9', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            bottomNavigationBar: DroptixBottomNav(
              currentIndex: 0,
              onTap: (_) {},
              unreadCount: 15,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnreadBadge), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
    });
  });

  group('T6.4: WhatsApp Option Tests', () {
    testWidgets('menampilkan opsi "Lanjut via WhatsApp" jika izinkanWa = true dan pembeli',
        (tester) async {
      final conv = ConversationModel(
        id: 77,
        listing: const ConversationListingModel(
          id: 42,
          judul: 'Konser Sheila on 7 Surabaya',
          harga: 350000,
          status: 'tersedia',
        ),
        lawan: const ConversationUserModel(id: 2, nama: 'Rina Penjual'),
        peran: 'pembeli',
        pesanTerakhir: 'Halo kak',
        waktuPesanTerakhir: DateTime.now(),
        belumDibaca: 0,
        izinkanWa: true,
      );

      final repo = _TestChatRepository(initialConversations: [conv]);

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 77,
            initialConversation: conv,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka popup menu 3 titik
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut via WhatsApp'), findsOneWidget);
      expect(find.text('Laporkan'), findsOneWidget);
      expect(find.text('Blokir pengguna'), findsOneWidget);
    });

    testWidgets('tidak menampilkan opsi "Lanjut via WhatsApp" jika izinkanWa = false',
        (tester) async {
      final conv = ConversationModel(
        id: 78,
        listing: const ConversationListingModel(
          id: 42,
          judul: 'Konser Sheila on 7 Surabaya',
          harga: 350000,
          status: 'tersedia',
        ),
        lawan: const ConversationUserModel(id: 2, nama: 'Rina Penjual'),
        peran: 'pembeli',
        pesanTerakhir: 'Halo kak',
        waktuPesanTerakhir: DateTime.now(),
        belumDibaca: 0,
        izinkanWa: false,
      );

      final repo = _TestChatRepository(initialConversations: [conv]);

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 78,
            initialConversation: conv,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut via WhatsApp'), findsNothing);
      expect(find.text('Laporkan'), findsOneWidget);
      expect(find.text('Blokir pengguna'), findsOneWidget);
    });

    testWidgets('tidak menampilkan opsi "Lanjut via WhatsApp" jika pengguna adalah penjual',
        (tester) async {
      final conv = ConversationModel(
        id: 79,
        listing: const ConversationListingModel(
          id: 42,
          judul: 'Konser Sheila on 7 Surabaya',
          harga: 350000,
          status: 'tersedia',
        ),
        lawan: const ConversationUserModel(id: 1, nama: 'Pembeli Satu'),
        peran: 'penjual',
        pesanTerakhir: 'Halo kak',
        waktuPesanTerakhir: DateTime.now(),
        belumDibaca: 0,
        izinkanWa: true,
      );

      final repo = _TestChatRepository(initialConversations: [conv]);

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 79,
            initialConversation: conv,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut via WhatsApp'), findsNothing);
    });

    testWidgets('mengetuk "Lanjut via WhatsApp" memanggil getWhatsAppUrl dan meluncurkan URL',
        (tester) async {
      final conv = ConversationModel(
        id: 80,
        listing: const ConversationListingModel(
          id: 42,
          judul: 'Konser Sheila on 7 Surabaya',
          harga: 350000,
          status: 'tersedia',
        ),
        lawan: const ConversationUserModel(id: 2, nama: 'Rina Penjual'),
        peran: 'pembeli',
        pesanTerakhir: 'Halo kak',
        waktuPesanTerakhir: DateTime.now(),
        belumDibaca: 0,
        izinkanWa: true,
      );

      final repo = _TestChatRepository(initialConversations: [conv]);
      Uri? launchedUri;

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 80,
            initialConversation: conv,
            chatRepository: repo,
            urlLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut via WhatsApp'));
      await tester.pumpAndSettle();

      expect(repo.requestedWaConvId, 80);
      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), 'https://wa.me/6281234567890?text=Halo%20Droptix');
    });

    testWidgets('menampilkan SnackBar error jika getWhatsAppUrl gagal',
        (tester) async {
      final conv = ConversationModel(
        id: 81,
        listing: const ConversationListingModel(
          id: 42,
          judul: 'Konser Sheila on 7 Surabaya',
          harga: 350000,
          status: 'tersedia',
        ),
        lawan: const ConversationUserModel(id: 2, nama: 'Rina Penjual'),
        peran: 'pembeli',
        pesanTerakhir: 'Halo kak',
        waktuPesanTerakhir: DateTime.now(),
        belumDibaca: 0,
        izinkanWa: true,
      );

      final repo = _TestChatRepository(initialConversations: [conv]);
      repo.throwOnWa = true;

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 81,
            initialConversation: conv,
            chatRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut via WhatsApp'));
      await tester.pumpAndSettle();

      expect(find.text('Penjual tidak mengizinkan WhatsApp.'), findsOneWidget);
    });
  });
}
