import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../chat/chat_socket_service.dart';
import '../events/event_detail_screen.dart';
import '../listings/listing_detail_screen.dart';
import 'notification_models.dart';
import 'notification_repository.dart';

/// Halaman daftar notifikasi in-app (tiket baru dari Pantau Tiket / event_alerts).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.notificationRepository,
    this.socketService,
  });

  final NotificationRepository? notificationRepository;
  final ChatSocketService? socketService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationRepository _repo;
  bool _repoInitialized = false;

  List<AppNotificationItem> _items = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final client = AuthScope.maybeOf(context)?.repository.client ??
          ApiClient(tokenStorage: TokenStorage());
      _repo = widget.notificationRepository ?? NotificationRepository(client);
      _repoInitialized = true;
      _fetchNotifications();
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _repo.getNotifications();
      if (mounted) {
        setState(() {
          _items = result.items;
          _unreadCount = result.unreadCount;
          _isLoading = false;
        });
        widget.socketService?.setUnreadNotificationsCount(result.unreadCount);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    if (_unreadCount == 0) return;
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
    });
    widget.socketService?.setUnreadNotificationsCount(0);
    try {
      await _repo.markAllAsRead();
    } catch (_) {
      _fetchNotifications();
    }
  }

  Future<void> _handleNotificationTap(AppNotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        _items = _items
            .map((n) => n.id == item.id ? n.copyWith(isRead: true) : n)
            .toList();
        _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      });
      widget.socketService?.setUnreadNotificationsCount(_unreadCount);
      _repo.markAsRead(item.id).catchError((_) {});
    }

    if (!mounted) return;
    if (item.listingId != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ListingDetailScreen(listingId: item.listingId!),
        ),
      );
    } else if (item.eventId != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(eventId: item.eventId!),
        ),
      );
    }
  }

  String _formatRelativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = createdAt.toLocal();
    return '${local.day} ${months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceHigh,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          title: Text('Notifikasi', style: AppTextStyles.titleMedium),
          actions: [
            if (_unreadCount > 0)
              TextButton(
                onPressed: _handleMarkAllAsRead,
                child: Text(
                  'Tandai dibaca',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: LoadingState(itemCount: 4),
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _fetchNotifications,
      );
    }

    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        message:
            'Belum ada notifikasi.\nAktifkan "Pantau Tiket" di halaman acara agar kami beritahu saat tiket baru tersedia.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceHigh,
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 32),
        itemCount: _items.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildNotificationRow(item);
        },
      ),
    );
  }

  Widget _buildNotificationRow(AppNotificationItem item) {
    return Material(
      color: item.isRead ? Colors.transparent : AppColors.surface,
      child: InkWell(
        onTap: () => _handleNotificationTap(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster / Ikon
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: item.eventPosterUrl != null &&
                          item.eventPosterUrl!.isNotEmpty
                      ? EventPoster(
                          title: item.eventName ?? item.title,
                          posterUrl: item.eventPosterUrl,
                          width: 48,
                          borderRadius: AppRadius.sm,
                        )
                      : Container(
                          color: AppColors.surfaceHigh,
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Konten
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.label.copyWith(
                              color: item.isRead
                                  ? AppColors.textPrimary
                                  : AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatRelativeTime(item.createdAt),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: item.isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Titik belum dibaca
              if (!item.isRead) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
