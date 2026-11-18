import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/auth/token_storage.dart';
import '../../core/network/api_config.dart';

/// Layanan Socket.IO tunggal untuk seluruh aplikasi.
/// Menangani koneksi, penyambungan ulang otomatis, serta penyebaran event
/// `message:new` dan `unread:update`.
class ChatSocketService {
  ChatSocketService({
    String? hostUrl,
    TokenStorage? tokenStorage,
  })  : hostUrl = hostUrl ?? ApiConfig.hostUrl,
        _tokenStorage = tokenStorage ?? TokenStorage();

  final String hostUrl;
  final TokenStorage _tokenStorage;

  io.Socket? _socket;
  io.Socket? get socket => _socket;

  /// Jumlah percakapan belum dibaca secara global untuk badge di tab Activity.
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Stream broadcast untuk event pesan baru masuk.
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;

  bool _isConnecting = false;

  bool get isConnected => _socket?.connected == true;

  /// Menyambungkan soket jika belum terhubung.
  Future<void> connect([String? explicitToken]) async {
    if (_socket?.connected == true || _isConnecting) return;
    _isConnecting = true;

    try {
      final token = explicitToken ?? await _tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        _isConnecting = false;
        return;
      }

      // Tutup koneksi sebelumnya jika ada
      _socket?.dispose();

      _socket = io.io(
        hostUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(10)
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[Socket.IO] Terhubung ke $hostUrl');
      });

      _socket!.onDisconnect((_) {
        debugPrint('[Socket.IO] Terputus');
      });

      _socket!.onConnectError((err) {
        debugPrint('[Socket.IO] Kesalahan koneksi: $err');
      });

      _socket!.on('message:new', (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _messageController.add(map);
        }
      });

      _socket!.on('unread:update', (data) {
        if (data is Map && data['chats'] != null) {
          final count = (data['chats'] as num).toInt();
          unreadCountNotifier.value = count;
        }
      });
    } catch (e) {
      debugPrint('[Socket.IO] Gagal inisialisasi: $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// Memutuskan koneksi soket (misalnya saat logout).
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    unreadCountNotifier.value = 0;
  }

  /// Memperbarui nilai unread secara manual jika diperlukan.
  void setUnreadCount(int count) {
    unreadCountNotifier.value = count;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    unreadCountNotifier.dispose();
  }
}
