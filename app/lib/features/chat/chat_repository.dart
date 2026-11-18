import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  final ApiClient _client;
  ApiClient get client => _client;

  /// Mengambil percakapan pembeli untuk listing tertentu (null jika belum ada).
  Future<ConversationModel?> getConversationForListing(int listingId) async {
    try {
      final res = await _client.dio.get<Map<String, dynamic>>(
        '/listings/$listingId/conversation',
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return ConversationModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw ApiException.fromDio(e);
    }
  }

  /// Membuat percakapan atomik dengan pesan pertama atau menambahkan pesan ke percakapan yang ada.
  Future<({ConversationModel conversation, ChatMessageModel message})>
      startListingConversation(int listingId, String isi) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/listings/$listingId/conversations',
        data: {'isi': isi},
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      final conv = ConversationModel.fromJson(
        data['conversation'] as Map<String, dynamic>,
      );
      final msg = ChatMessageModel.fromJson(
        data['message'] as Map<String, dynamic>,
      );
      return (conversation: conv, message: msg);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengambil daftar percakapan (kotak masuk chat).
  Future<List<ConversationModel>> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _client.dio.get<Map<String, dynamic>>(
        '/conversations',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      final list = res.data?['data'] as List<dynamic>? ?? [];
      return list
          .map((item) =>
              ConversationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengambil detail satu percakapan.
  Future<ConversationModel> getConversation(int conversationId) async {
    try {
      final res = await _client.dio.get<Map<String, dynamic>>(
        '/conversations/$conversationId',
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      return ConversationModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengambil riwayat pesan berpaginasi mundur.
  Future<({List<ChatMessageModel> messages, bool adaLebihLama})> getMessages(
    int conversationId, {
    int? before,
    int limit = 30,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (before != null) query['before'] = before;

      final res = await _client.dio.get<Map<String, dynamic>>(
        '/conversations/$conversationId/messages',
        queryParameters: query,
      );
      final list = res.data?['data'] as List<dynamic>? ?? [];
      final meta = res.data?['meta'] as Map<String, dynamic>?;
      final adaLebihLama = meta?['ada_lebih_lama'] as bool? ?? false;

      final messages = list
          .map((item) =>
              ChatMessageModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return (messages: messages, adaLebihLama: adaLebihLama);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengirim pesan dalam percakapan yang ada.
  Future<ChatMessageModel> sendMessage(int conversationId, String isi) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/conversations/$conversationId/messages',
        data: {'isi': isi},
      );
      final data = res.data?['data'] as Map<String, dynamic>;
      return ChatMessageModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Menandai percakapan telah dibaca sampai sekarang.
  Future<({int belumDibaca, int chatsBelumDibaca})> markAsRead(
    int conversationId,
  ) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/conversations/$conversationId/read',
      );
      final data = res.data?['data'] as Map<String, dynamic>? ?? {};
      return (
        belumDibaca: (data['belum_dibaca'] as num?)?.toInt() ?? 0,
        chatsBelumDibaca: (data['chats_belum_dibaca'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengambil jumlah percakapan yang memiliki pesan belum dibaca.
  Future<int> getUnreadChatsCount() async {
    try {
      final res = await _client.dio.get<Map<String, dynamic>>('/me/unread');
      final data = res.data?['data'] as Map<String, dynamic>?;
      return (data?['chats'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
