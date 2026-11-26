/// Model satu item notifikasi in-app Droptix.
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.eventId,
    this.eventName,
    this.eventPosterUrl,
    this.listingId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final int? eventId;
  final String? eventName;
  final String? eventPosterUrl;
  final int? listingId;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?) ?? 'new_ticket',
      title: (json['title'] as String?) ?? 'Notifikasi',
      body: (json['body'] as String?) ?? '',
      eventId: (json['event_id'] as num?)?.toInt(),
      eventName: json['event_nama'] as String?,
      eventPosterUrl: json['event_poster_url'] as String?,
      listingId: (json['listing_id'] as num?)?.toInt(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] is String
          ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      eventId: eventId,
      eventName: eventName,
      eventPosterUrl: eventPosterUrl,
      listingId: listingId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

/// Hasil daftar notifikasi beserta jumlah belum dibaca.
class NotificationsResult {
  const NotificationsResult({
    required this.items,
    required this.unreadCount,
  });

  final List<AppNotificationItem> items;
  final int unreadCount;
}
