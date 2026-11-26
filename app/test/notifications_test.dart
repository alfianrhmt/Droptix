import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droptix/features/notifications/notification_models.dart';
import 'package:droptix/features/notifications/notification_repository.dart';
import 'package:droptix/features/notifications/notifications_screen.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({required this.items});

  List<AppNotificationItem> items;
  int markReadCalls = 0;
  int markAllReadCalls = 0;

  @override
  Future<NotificationsResult> getNotifications() async {
    final unread = items.where((i) => !i.isRead).length;
    return NotificationsResult(items: List.of(items), unreadCount: unread);
  }

  @override
  Future<int> getUnreadCount() async => items.where((i) => !i.isRead).length;

  @override
  Future<void> markAsRead(int id) async {
    markReadCalls++;
    items = items
        .map((i) => i.id == id ? i.copyWith(isRead: true) : i)
        .toList();
  }

  @override
  Future<void> markAllAsRead() async {
    markAllReadCalls++;
    items = items.map((i) => i.copyWith(isRead: true)).toList();
  }
}

void main() {
  testWidgets('NotificationsScreen menampilkan daftar notifikasi dan tandai semua dibaca di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeNotificationRepository(
      items: [
        AppNotificationItem(
          id: 1,
          type: 'new_ticket',
          title: 'Tiket Baru Tersedia',
          body: 'Avengers Doomsday · 2 tiket Rp 25.000 di XXI Tunjungan Plaza',
          eventId: 14,
          eventName: 'Avengers Doomsday',
          listingId: 18,
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(notificationRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Tiket Baru Tersedia'), findsOneWidget);
    expect(find.textContaining('Avengers Doomsday'), findsOneWidget);
    expect(find.text('Tandai dibaca'), findsOneWidget);

    await tester.tap(find.text('Tandai dibaca'));
    await tester.pumpAndSettle();

    expect(repo.markAllReadCalls, 1);
    expect(find.text('Tandai dibaca'), findsNothing);
  });

  testWidgets('NotificationsScreen menampilkan empty state saat belum ada notifikasi',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = _FakeNotificationRepository(items: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(notificationRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada notifikasi.'), findsOneWidget);
    expect(find.text('Tandai dibaca'), findsNothing);
  });
}
