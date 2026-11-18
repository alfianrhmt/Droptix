import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/empty_state.dart';
import 'package:droptix/features/chat/chat_models.dart';
import 'package:droptix/features/chat/chat_repository.dart';
import 'package:droptix/features/chat/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droptix/features/moderation/moderation_repository.dart';
import 'package:droptix/features/moderation/report_bottom_sheet.dart';
import 'package:droptix/features/profile/blocked_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(tokenStorage: TokenStorage()));

  @override
  Future<UserModel> getMe() async {
    return const UserModel(
      id: 1,
      nama: 'Pembeli Satu',
      email: 'buyer1@example.com',
    );
  }
}

class _FakeChatRepository implements ChatRepository {
  @override
  ApiClient get client => ApiClient(tokenStorage: TokenStorage());

  @override
  Future<List<ConversationModel>> getConversations({int page = 1, int limit = 20}) async => [];

  @override
  Future<ConversationModel?> getConversationForListing(int listingId) async => null;

  @override
  Future<ConversationModel> getConversation(int conversationId) async {
    throw UnimplementedError();
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
    throw UnimplementedError();
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
  Future<int> getUnreadChatsCount() async => 0;

  @override
  Future<String> getWhatsAppUrl(int conversationId) async => '';
}

class _MockModerationRepository extends ModerationRepository {
  _MockModerationRepository() : super(ApiClient(tokenStorage: TokenStorage()));

  String? lastReportedType;
  int? lastReportedId;
  String? lastReportedAlasan;
  String? lastReportedKeterangan;

  int? lastBlockedUserId;
  int? lastUnblockedUserId;
  List<BlockedUserModel> mockBlockedUsers = [];

  @override
  Future<int> report({
    required String targetType,
    required int targetId,
    required String alasan,
    String? keterangan,
  }) async {
    lastReportedType = targetType;
    lastReportedId = targetId;
    lastReportedAlasan = alasan;
    lastReportedKeterangan = keterangan;
    return 101;
  }

  @override
  Future<bool> blockUser(int userId) async {
    lastBlockedUserId = userId;
    return true;
  }

  @override
  Future<bool> unblockUser(int userId) async {
    lastUnblockedUserId = userId;
    mockBlockedUsers.removeWhere((u) => u.id == userId);
    return true;
  }

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    return List.of(mockBlockedUsers);
  }
}

Future<Widget> buildTestApp({required Widget child}) async {
  final tokenStorage = TokenStorage();
  await tokenStorage.saveSession(
    'test-token',
    const UserModel(
      id: 1,
      nama: 'Pembeli Satu',
      email: 'buyer1@example.com',
    ),
  );

  final authController = AuthController(
    repository: _FakeAuthRepository(),
    tokenStorage: tokenStorage,
  );
  await authController.restoreSession();

  return AuthScope(
    controller: authController,
    child: MaterialApp(
      // Matikan animasi agar pumpAndSettle tidak hang karena counter TextField
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsBuilder(),
          },
        ),
      ),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 740)),
        child: child,
      ),
    ),
  );
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // Helper: pump yang aman untuk animasi sederhana tanpa risiko hang
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('T7.2: ReportBottomSheet Tests', () {
    testWidgets('menampilkan 5 opsi alasan pelaporan dan kolom keterangan', (tester) async {
      final mockRepo = _MockModerationRepository();

      await tester.pumpWidget(
        await buildTestApp(
          child: Scaffold(
            body: ReportBottomSheet(
              targetType: 'listing',
              targetId: 42,
              targetTitle: 'Tiket Konser Sheila on 7',
              repository: mockRepo,
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Laporkan Listing'), findsOneWidget);
      expect(find.text('Tiket Konser Sheila on 7'), findsOneWidget);
      expect(find.text('Penipuan atau transaksi mencurigakan'), findsOneWidget);
      expect(find.text('Tiket palsu atau tidak valid'), findsOneWidget);
      expect(find.text('Spam atau iklan berulang'), findsOneWidget);
      expect(find.text('Konten atau perilaku tidak pantas'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);
      expect(find.byKey(const Key('report_keterangan_field')), findsOneWidget);
      expect(find.byKey(const Key('report_submit_button')), findsOneWidget);
    });

    testWidgets('mengirim laporan dengan alasan terpilih dan keterangan ke repositori', (tester) async {
      final mockRepo = _MockModerationRepository();

      await tester.pumpWidget(
        await buildTestApp(
          child: Scaffold(
            body: ReportBottomSheet(
              targetType: 'user',
              targetId: 99,
              targetTitle: 'Penjual Nakal',
              repository: mockRepo,
            ),
          ),
        ),
      );
      await settle(tester);

      // Pilih alasan 'Spam atau iklan berulang'
      await tester.tap(find.byKey(const Key('report_reason_spam')));
      await settle(tester);

      // Isi keterangan
      await tester.enterText(
        find.byKey(const Key('report_keterangan_field')),
        'Mengirim pesan berulang kali',
      );
      await settle(tester);

      // Tekan tombol Kirim Laporan
      await tester.tap(find.byKey(const Key('report_submit_button')));
      await settle(tester);

      expect(mockRepo.lastReportedType, 'user');
      expect(mockRepo.lastReportedId, 99);
      expect(mockRepo.lastReportedAlasan, 'spam');
      expect(mockRepo.lastReportedKeterangan, 'Mengirim pesan berulang kali');
      expect(
        find.text('Laporan Anda telah diterima dan akan ditinjau tim Droptix.'),
        findsOneWidget,
      );
    });
  });

  group('T7.2: BlockedUsersScreen Tests', () {
    testWidgets('menampilkan EmptyState saat daftar blokir kosong', (tester) async {
      final mockRepo = _MockModerationRepository();
      mockRepo.mockBlockedUsers = [];

      await tester.pumpWidget(
        await buildTestApp(
          child: BlockedUsersScreen(
            moderationRepository: mockRepo,
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Belum ada pengguna yang kamu blokir.'), findsOneWidget);
    });

    testWidgets('menampilkan daftar pengguna diblokir dan aksi unblock berhasil', (tester) async {
      final mockRepo = _MockModerationRepository();
      mockRepo.mockBlockedUsers = [
        const BlockedUserModel(id: 2, nama: 'Penjual Dua'),
        const BlockedUserModel(id: 3, nama: 'Penjual Tiga'),
      ];

      await tester.pumpWidget(
        await buildTestApp(
          child: BlockedUsersScreen(
            moderationRepository: mockRepo,
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Penjual Dua'), findsOneWidget);
      expect(find.text('Penjual Tiga'), findsOneWidget);

      // Ketuk Buka Blokir untuk Penjual Dua
      await tester.tap(find.byKey(const Key('unblock_button_2')));
      await settle(tester);

      // Dialog konfirmasi muncul
      expect(find.text('Buka blokir Penjual Dua?'), findsOneWidget);

      // Konfirmasi buka blokir
      await tester.tap(find.text('Buka Blokir').last);
      await settle(tester);

      expect(mockRepo.lastUnblockedUserId, 2);
      expect(find.text('Blokir terhadap Penjual Dua telah dibuka.'), findsOneWidget);
      expect(find.text('Penjual Dua'), findsNothing);
      expect(find.text('Penjual Tiga'), findsOneWidget);
    });
  });

  group('T7.2: ChatScreen Block & Report Integration Tests', () {
    testWidgets('menu "Laporkan" di ChatScreen membuka ReportBottomSheet', (tester) async {
      final mockRepo = _MockModerationRepository();
      final conv = ConversationModel(
        id: 10,
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

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 10,
            initialConversation: conv,
            chatRepository: _FakeChatRepository(),
            moderationRepository: mockRepo,
          ),
        ),
      );
      await settle(tester);

      // Buka popup menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await settle(tester);

      // Pilih Laporkan
      await tester.tap(find.text('Laporkan'));
      await settle(tester);

      expect(find.byType(ReportBottomSheet), findsOneWidget);
      expect(find.text('Laporkan Pengguna'), findsOneWidget);
      // "Rina Penjual" muncul di AppBar ChatScreen + di subtitle ReportBottomSheet
      expect(find.text('Rina Penjual'), findsWidgets);
    });

    testWidgets('menu "Blokir pengguna" di ChatScreen menampilkan konfirmasi dan mengunci input chat',
        (tester) async {
      final mockRepo = _MockModerationRepository();
      final conv = ConversationModel(
        id: 11,
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

      await tester.pumpWidget(
        await buildTestApp(
          child: ChatScreen(
            conversationId: 11,
            initialConversation: conv,
            chatRepository: _FakeChatRepository(),
            moderationRepository: mockRepo,
          ),
        ),
      );
      await settle(tester);

      // Buka popup menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await settle(tester);

      // Pilih Blokir pengguna
      await tester.tap(find.text('Blokir pengguna'));
      await settle(tester);

      // Dialog konfirmasi blokir
      expect(find.text('Blokir Rina Penjual?'), findsOneWidget);

      // Konfirmasi Blokir
      await tester.tap(find.text('Blokir').last);
      await settle(tester);

      expect(mockRepo.lastBlockedUserId, 2);
      expect(find.text('Rina Penjual telah diblokir.'), findsOneWidget);

      // Input chat sekarang diganti teks pemblokiran per DESIGN.md
      expect(
        find.text('Kamu tidak bisa mengirim pesan di percakapan ini.'),
        findsOneWidget,
      );
    });
  });
}
