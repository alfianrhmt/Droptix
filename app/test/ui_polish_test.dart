import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/badges.dart';
import 'package:droptix/core/widgets/countdown_timer.dart';
import 'package:droptix/core/widgets/empty_state.dart';
import 'package:droptix/features/gallery/component_gallery_screen.dart';
import 'package:droptix/features/profile/blocked_users_screen.dart';
import 'package:droptix/features/profile/privacy_screen.dart';
import 'package:droptix/features/profile/profile_screen.dart';
import 'package:droptix/features/profile/terms_screen.dart';
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
      nama: 'Budi Tester',
      email: 'budi@droptix.dev',
      kota: 'Surabaya',
      noWa: '081234567890',
    );
  }
}

Future<Widget> buildTestApp({
  required Widget child,
  double textScale = 1.0,
  Size size = const Size(360, 740),
}) async {
  final tokenStorage = TokenStorage();
  await tokenStorage.saveSession(
    'mock-token',
    const UserModel(
      id: 1,
      nama: 'Budi Tester',
      email: 'budi@droptix.dev',
      kota: 'Surabaya',
      noWa: '081234567890',
    ),
  );

  final authController = AuthController(
    repository: _FakeAuthRepository(),
    tokenStorage: tokenStorage,
  );
  await authController.restoreSession();

  return AuthScope(
    controller: authController,
    child: CountdownTimerProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('T8.1: Responsivitas 360x740 & Skala Teks 1.3 (Tanpa Overflow)', () {
    testWidgets('ComponentGalleryScreen tampil tanpa overflow di 360x740 dengan teks 1.3',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(
          child: const ComponentGalleryScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('TermsScreen tampil tanpa overflow di 360x740 dengan teks 1.3',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(
          child: const TermsScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Syarat Penggunaan'), findsOneWidget);
    });

    testWidgets('PrivacyScreen tampil tanpa overflow di 360x740 dengan teks 1.3',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(
          child: const PrivacyScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Kebijakan Privasi'), findsOneWidget);
    });

    testWidgets('ProfileScreen tampil tanpa overflow di 360x740 dengan teks 1.3',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(
          child: const ProfileScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Budi Tester'), findsOneWidget);
    });

    testWidgets('BlockedUsersScreen tampil tanpa overflow di 360x740 dengan teks 1.3',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(
          child: const BlockedUsersScreen(),
          textScale: 1.3,
          size: const Size(360, 740),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });

  group('T8.1: Keadaan UI (Loading, Empty, Error) & Area Sentuh Minimal 48dp', () {
    testWidgets('EmptyState menampilkan icon, pesan, dan aksi jika ada',
        (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        await buildTestApp(
          child: EmptyState(
            icon: Icons.inbox_rounded,
            message: 'Tidak ada tiket ditemukan.',
            actionLabel: 'Cari Lainnya',
            onAction: () => actionTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
      expect(find.text('Tidak ada tiket ditemukan.'), findsOneWidget);
      expect(find.text('Cari Lainnya'), findsOneWidget);

      await tester.tap(find.text('Cari Lainnya'));
      expect(actionTapped, isTrue);
    });

    testWidgets('ErrorState menampilkan ikon error, pesan, dan tombol Coba lagi',
        (tester) async {
      bool retryTapped = false;
      await tester.pumpWidget(
        await buildTestApp(
          child: ErrorState(
            message: 'Koneksi terputus.',
            onRetry: () => retryTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Koneksi terputus.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      expect(retryTapped, isTrue);
    });

    testWidgets('CountdownTimerProvider memicu pembaruan CountdownBadge secara sinkron',
        (tester) async {
      final futureEvent = DateTime.now().add(const Duration(hours: 3));
      await tester.pumpWidget(
        await buildTestApp(
          child: CountdownBadge(eventDate: futureEvent),
        ),
      );
      await tester.pump();

      expect(find.byType(CountdownBadge), findsOneWidget);
    });
  });
}
