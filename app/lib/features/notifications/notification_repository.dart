import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'notification_models.dart';

/// Klien API untuk fitur notifikasi in-app Droptix.
class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationsResult> getNotifications() async {
    try {
      final res =
          await _apiClient.dio.get<Map<String, dynamic>>('/notifications');
      final list = res.data?['data'] as List<dynamic>? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      return NotificationsResult(
        items: list
            .map((e) => AppNotificationItem.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        unreadCount: (meta['unread_count'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _apiClient.dio
          .get<Map<String, dynamic>>('/notifications/unread-count');
      final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
      return (data['unread_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _apiClient.dio
          .patch<Map<String, dynamic>>('/notifications/$id/read');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiClient.dio
          .post<Map<String, dynamic>>('/notifications/read-all');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
