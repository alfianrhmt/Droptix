import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/auth/user_model.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/network/api_error.dart';
import 'package:droptix/core/widgets/event_poster.dart';
import 'package:droptix/features/chat/chat_socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeErrorAdapter implements HttpClientAdapter {
  _FakeErrorAdapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('T8.2: Penanganan Jaringan & Error Terstruktur', () {
    test('mengonversi Dio connectionError menjadi ApiException dengan pesan ramah', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/listings'),
        type: DioExceptionType.connectionError,
        error: 'SocketException: OS Error: Connection refused',
      );

      final apiErr = ApiException.fromDio(dioErr);
      expect(apiErr.code, 'NETWORK_ERROR');
      expect(apiErr.message, 'Tidak dapat terhubung ke server. Periksa internetmu.');
    });

    test('mengonversi Dio connectionTimeout / receiveTimeout menjadi TIMEOUT', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/listings'),
        type: DioExceptionType.connectionTimeout,
      );

      final apiErr = ApiException.fromDio(dioErr);
      expect(apiErr.code, 'TIMEOUT');
      expect(apiErr.message, 'Koneksi ke server melebihi batas waktu. Coba lagi.');
    });

    test('interceptor otomatis menghapus sesi & memicu logout saat token ditolak 401 UNAUTHORIZED',
        () async {
      final tokenStorage = TokenStorage();
      await tokenStorage.saveSession(
        'expired-token',
        const UserModel(id: 1, nama: 'User', email: 'u@example.com'),
      );

      String? unauthorizedCode;
      final dio = Dio();
      dio.httpClientAdapter = _FakeErrorAdapter(401, {
        'error': {
          'code': 'UNAUTHORIZED',
          'message': 'Token kedaluwarsa atau tidak valid.',
        },
      });

      final client = ApiClient(
        tokenStorage: tokenStorage,
        dio: dio,
        onUnauthorized: (code) {
          unauthorizedCode = code;
        },
      );

      // Jalankan request nyata melewati pipeline interceptor
      await expectLater(
        () => client.dio.get<Map<String, dynamic>>('/me'),
        throwsA(isA<DioException>()),
      );

      // Verifikasi token terhapus dan callback logout dipanggil
      expect(unauthorizedCode, 'UNAUTHORIZED');
      final remainingToken = await tokenStorage.readToken();
      expect(remainingToken, isNull);
    });

    test('interceptor otomatis memutus sesi jika akun berstatus ACCOUNT_BANNED',
        () async {
      final tokenStorage = TokenStorage();
      await tokenStorage.saveSession(
        'banned-token',
        const UserModel(id: 2, nama: 'Banned', email: 'b@example.com'),
      );

      String? bannedCode;
      final dio = Dio();
      dio.httpClientAdapter = _FakeErrorAdapter(403, {
        'error': {
          'code': 'ACCOUNT_BANNED',
          'message': 'Akun Anda telah dibekukan.',
        },
      });

      final client = ApiClient(
        tokenStorage: tokenStorage,
        dio: dio,
        onUnauthorized: (code) {
          bannedCode = code;
        },
      );

      await expectLater(
        () => client.dio.get<Map<String, dynamic>>('/me/listings'),
        throwsA(isA<DioException>()),
      );

      expect(bannedCode, 'ACCOUNT_BANNED');
      final remainingToken = await tokenStorage.readToken();
      expect(remainingToken, isNull);
    });

    testWidgets('EventPoster menampilkan fallback poster bergradasi saat URL gambar tidak valid',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventPoster(
              title: 'Konser Festival Musik 2026',
              categorySlug: 'konser-festival',
              posterUrl: null, // Tanpa URL
              width: 120,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Konser Festival Musik 2026'), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    test('ChatSocketService dapat memutus koneksi dan mereset unreadCountNotifier', () {
      final tokenStorage = TokenStorage();
      final socketService = ChatSocketService(tokenStorage: tokenStorage);

      socketService.unreadCountNotifier.value = 5;
      expect(socketService.unreadCountNotifier.value, 5);

      socketService.disconnect();
      expect(socketService.unreadCountNotifier.value, 0);
      expect(socketService.isConnected, isFalse);
    });
  });
}
