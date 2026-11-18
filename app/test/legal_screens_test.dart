import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
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
      nama: 'Budi Santoso',
      email: 'budi@example.com',
      kota: 'Surabaya',
      noWa: '08123456789',
    );
  }
}

Future<Widget> buildTestApp({required Widget child}) async {
  final tokenStorage = TokenStorage();
  await tokenStorage.saveSession(
    'mock-token',
    const UserModel(
      id: 1,
      nama: 'Budi Santoso',
      email: 'budi@example.com',
      kota: 'Surabaya',
      noWa: '08123456789',
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
      theme: buildAppTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(360, 740)),
          child: child,
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

  group('T7.3: Legal Screens Tests (FR-15)', () {
    testWidgets('TermsScreen menampilkan judul dan konten peran Droptix & larangan',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(child: const TermsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Syarat Penggunaan'), findsOneWidget);
      expect(find.text('Syarat & Ketentuan Layanan'), findsOneWidget);
      expect(find.text('1. Peran Droptix'), findsOneWidget);
      expect(find.text('2. Larangan Pengguna'), findsOneWidget);
      expect(find.text('3. Transaksi & Kehati-hatian'), findsOneWidget);
      expect(find.text('4. Pelaporan Pelanggaran'), findsOneWidget);
      expect(find.text('5. Penghentian & Penghapusan Akun'), findsOneWidget);
    });

    testWidgets('PrivacyScreen menampilkan kebijakan privasi sesuai PRD.md FR-15',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(child: const PrivacyScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Kebijakan Privasi Droptix'), findsOneWidget);
      expect(find.text('1. Informasi yang Kami Kumpulkan'), findsOneWidget);
      expect(find.text('2. Penggunaan Data Lokasi (GPS)'), findsOneWidget);
      expect(find.text('3. Perlindungan Privasi Penjual & Pembeli'), findsOneWidget);
      expect(find.text('4. Penggunaan Data untuk Keamanan & Moderasi'), findsOneWidget);
      expect(find.text('5. Permintaan Penghapusan Data & Akun'), findsOneWidget);
    });

    testWidgets('ProfileScreen menavigasi ke TermsScreen dan PrivacyScreen saat diketuk',
        (tester) async {
      await tester.pumpWidget(
        await buildTestApp(child: const ProfileScreen()),
      );
      await tester.pumpAndSettle();

      // Ketuk Syarat Penggunaan
      await tester.tap(find.text('Syarat Penggunaan'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.text('1. Peran Droptix'), findsOneWidget);

      // Kembali
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Ketuk Kebijakan Privasi
      await tester.tap(find.text('Kebijakan Privasi'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(find.text('2. Penggunaan Data Lokasi (GPS)'), findsOneWidget);
    });
  });
}
