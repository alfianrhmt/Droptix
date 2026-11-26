import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/network/api_error.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';
import 'package:droptix/features/auth/register_screen.dart';
import 'package:droptix/features/profile/change_password_screen.dart';
import 'package:droptix/features/profile/edit_profile_screen.dart';
import 'package:droptix/features/profile/profile_screen.dart';
import 'package:droptix/features/shell/app_shell.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(super.client);

  UserModel fakeUser = const UserModel(
    id: 1,
    username: 'rakapratama',
    nama: 'Raka Pratama',
    email: 'raka@droptix.dev',
    noWa: '6281234567801',
    kota: 'Surabaya',
  );

  bool failGetMe = false;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return AuthResult(token: 'jwt-token-123', user: fakeUser);
  }

  @override
  Future<AuthResult> register({
    String? username,
    required String nama,
    required String email,
    required String password,
    required bool setujuSyarat,
    String? noWa,
    String? kota,
  }) async {
    fakeUser = UserModel(
      id: 2,
      username: username ?? 'user2',
      nama: nama,
      email: email,
      noWa: noWa,
      kota: kota,
    );
    return AuthResult(token: 'jwt-reg-456', user: fakeUser);
  }

  @override
  Future<UserModel> getMe() async {
    if (failGetMe) {
      throw const ApiException(
        code: 'UNAUTHORIZED',
        message: 'Token kedaluwarsa.',
        statusCode: 401,
      );
    }
    return fakeUser;
  }

  @override
  Future<UserModel> updateMe({
    String? username,
    String? nama,
    String? noWa,
    String? kota,
    String? fotoUrl,
    bool removeFoto = false,
  }) async {
    fakeUser = UserModel(
      id: fakeUser.id,
      username: username ?? fakeUser.username,
      nama: nama ?? fakeUser.nama,
      email: fakeUser.email,
      noWa: noWa ?? fakeUser.noWa,
      kota: kota ?? fakeUser.kota,
      fotoUrl: removeFoto ? null : (fotoUrl ?? fakeUser.fotoUrl),
    );
    return fakeUser;
  }

  @override
  Future<String> uploadProfilePhoto(
    dynamic bytes, {
    String filename = 'avatar.jpg',
  }) async {
    return '/uploads/fake-avatar.jpg';
  }

  @override
  Future<void> updatePassword({
    required String passwordLama,
    required String passwordBaru,
  }) async {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapWithAuth(
    AuthController auth,
    Widget child, {
    double textScale = 1.0,
  }) {
    return AuthScope(
      controller: auth,
      child: CountdownTimerProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: widget!,
          ),
          home: child,
        ),
      ),
    );
  }

  AuthController createFakeAuth() {
    final storage = TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final repo = _FakeAuthRepository(client);
    return AuthController(repository: repo, tokenStorage: storage);
  }

  test('ApiException.fromDio memetakan error seragam dan field details', () {
    final dioErr = DioException(
      requestOptions: RequestOptions(path: '/auth/register'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/register'),
        statusCode: 422,
        data: {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Data tidak valid',
            'details': [
              {'field': 'email', 'message': 'Format email tidak valid.'},
            ],
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );

    final parsed = ApiException.fromDio(dioErr);
    expect(parsed.code, 'VALIDATION_ERROR');
    expect(parsed.statusCode, 422);
    expect(parsed.fieldErrors['email'], 'Format email tidak valid.');
  });

  test('AuthController menyimpan & memulihkan sesi serta logout bersih',
      () async {
    final storage = TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final repo = _FakeAuthRepository(client);
    final auth = AuthController(repository: repo, tokenStorage: storage);

    await auth.login(email: 'raka@droptix.dev', password: 'password123');
    expect(auth.isLoggedIn, isTrue);
    expect(await storage.readToken(), 'jwt-token-123');

    // Simulasi buka ulang aplikasi
    final auth2 = AuthController(repository: repo, tokenStorage: storage);
    await auth2.restoreSession();
    expect(auth2.isLoggedIn, isTrue);
    expect(auth2.user?.email, 'raka@droptix.dev');

    // Token ditolak server saat restore -> otomatis logout
    repo.failGetMe = true;
    await auth2.restoreSession();
    expect(auth2.isLoggedIn, isFalse);
    expect(await storage.readToken(), isNull);
  });

  testWidgets(
      'RegisterScreen mewajibkan centang persetujuan syarat dan tampil bersih di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final auth = createFakeAuth();
    await tester.pumpWidget(
      wrapWithAuth(auth, const RegisterScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'sariindah');
    await tester.enterText(find.byType(TextField).at(1), 'Sari Indah');
    await tester.enterText(find.byType(TextField).at(2), 'sari@droptix.dev');
    await tester.enterText(find.byType(TextField).at(3), 'password123');

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Daftar'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Kamu wajib menyetujui Syarat Penggunaan & Kebijakan Privasi.',
      ),
      findsOneWidget,
    );
    expect(auth.isLoggedIn, isFalse);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Daftar'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar'));
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn, isTrue);
  });

  testWidgets('Alur login saat aksi: tamu ketuk Sell -> Login -> buka Sell',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final auth = createFakeAuth();
    await auth.restoreSession();

    await tester.pumpWidget(wrapWithAuth(auth, const AppShell()));
    await tester.pumpAndSettle();

    // Tamu mengetuk tab Sell
    await tester.tap(find.byTooltip('Sell'));
    await tester.pumpAndSettle();

    // Muncul LoginScreen
    expect(find.text('Masuk ke Droptix'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'raka@droptix.dev');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    // Setelah login, otomatis lanjut ke tab Sell (Opsi A: daftar Penjualan & tombol Jual Tiket)
    expect(auth.isLoggedIn, isTrue);
    expect(find.text('Penjualan'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Jual Tiket'), findsOneWidget);

    // Ketuk tombol Jual Tiket untuk membuka wizard 5-langkah
    await tester.tap(find.widgetWithText(ElevatedButton, 'Jual Tiket'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jual Tiket (1/5)'), findsOneWidget);
  });

  testWidgets(
      'ProfileScreen, EditProfileScreen, dan ChangePasswordScreen tampil tanpa overflow di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final auth = createFakeAuth();
    await auth.login(email: 'raka@droptix.dev', password: 'password123');

    await tester.pumpWidget(
      wrapWithAuth(auth, const AppBackground(child: Scaffold(body: ProfileScreen())),
          textScale: 1.3),
    );
    await tester.pumpAndSettle();
    expect(find.text('Raka Pratama'), findsOneWidget);
    expect(find.text('Edit profil'), findsOneWidget);

    await tester.pumpWidget(
      wrapWithAuth(auth, const EditProfileScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    expect(find.text('Simpan perubahan'), findsOneWidget);

    await tester.pumpWidget(
      wrapWithAuth(auth, const ChangePasswordScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ubah password'), findsOneWidget);
  });

  testWidgets(
      'EditProfileScreen menampilkan foto profil dan dapat memilih foto baru',
      (tester) async {
    final auth = createFakeAuth();
    await auth.login(email: 'raka@droptix.dev', password: 'password123');

    await tester.pumpWidget(
      wrapWithAuth(
        auth,
        EditProfileScreen(
          pickPhotoBytes: (source) async => Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.text('Ubah Foto Profil'), findsOneWidget);

    // Ketuk tombol Ubah Foto Profil
    await tester.tap(find.text('Ubah Foto Profil'));
    await tester.pumpAndSettle();

    // Muncul modal opsi foto
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
    expect(find.text('Ambil Foto Kamera'), findsOneWidget);

    // Pilih dari galeri
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();

    // Simpan perubahan
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pumpAndSettle();

    expect(auth.user?.fotoUrl, equals('/uploads/fake-avatar.jpg'));
  });
}

