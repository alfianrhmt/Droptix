import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../features/auth/login_screen.dart';
import '../network/api_error.dart';
import 'auth_repository.dart';
import 'token_storage.dart';
import 'user_model.dart';

/// Mengelola sesi pengguna (tamu atau masuk), penyimpanan token, dan alur login saat aksi.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.repository,
    required this.tokenStorage,
  });

  final AuthRepository repository;
  final TokenStorage tokenStorage;

  UserModel? _user;
  bool _isRestoring = true;
  bool _isBusy = false;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isRestoring => _isRestoring;
  bool get isBusy => _isBusy;

  /// Memulihkan sesi tersimpan saat aplikasi dibuka.
  Future<void> restoreSession() async {
    _isRestoring = true;
    notifyListeners();

    try {
      final token = await tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        _user = null;
        return;
      }

      _user = await tokenStorage.readUser();
      notifyListeners();

      // Verifikasi token dan ambil profil terbaru dari server
      try {
        final fresh = await repository.getMe();
        _user = fresh;
        await tokenStorage.saveUser(fresh);
      } on ApiException catch (e) {
        if (e.code == 'UNAUTHORIZED' || e.code == 'ACCOUNT_BANNED') {
          await tokenStorage.clear();
          _user = null;
        }
        // Error jaringan: tetap pertahankan sesi cache sementara
      }
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      final res = await repository.login(email: email, password: password);
      await tokenStorage.saveSession(res.token, res.user);
      _user = res.user;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> register({
    String? username,
    required String nama,
    required String email,
    required String password,
    required bool setujuSyarat,
    String? noWa,
    String? kota,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      final res = await repository.register(
        username: username,
        nama: nama,
        email: email,
        password: password,
        setujuSyarat: setujuSyarat,
        noWa: noWa,
        kota: kota,
      );
      await tokenStorage.saveSession(res.token, res.user);
      _user = res.user;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? nama,
    String? noWa,
    String? kota,
    String? fotoUrl,
    bool removeFoto = false,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      final updated = await repository.updateMe(
        username: username,
        nama: nama,
        noWa: noWa,
        kota: kota,
        fotoUrl: fotoUrl,
        removeFoto: removeFoto,
      );
      _user = updated;
      await tokenStorage.saveUser(updated);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String> uploadProfilePhoto(Uint8List bytes) async {
    return await repository.uploadProfilePhoto(bytes);
  }

  Future<void> changePassword({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      await repository.updatePassword(
        passwordLama: passwordLama,
        passwordBaru: passwordBaru,
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await tokenStorage.clear();
    _user = null;
    notifyListeners();
  }

  /// Dipanggil interceptor ketika token ditolak server (401/403).
  void handleForcedLogout() {
    if (_user == null) return;
    _user = null;
    notifyListeners();
  }

  /// Alur "login saat aksi" untuk tamu:
  /// jika sudah masuk langsung jalankan [onAuthenticated],
  /// jika belum, buka [LoginScreen] lalu jalankan setelah berhasil masuk.
  Future<void> requireAuthAction(
    BuildContext context,
    VoidCallback onAuthenticated,
  ) async {
    if (isLoggedIn) {
      onAuthenticated();
      return;
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (ok == true && isLoggedIn && context.mounted) {
      onAuthenticated();
    }
  }
}

/// InheritedNotifier untuk mengakses [AuthController] di seluruh widget tree.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  static AuthController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }
}

