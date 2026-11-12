import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'badges.dart';

// ---------------------------------------------------------------------------
// ConversationRow
// ---------------------------------------------------------------------------

class ConversationData {
  const ConversationData({
    required this.id,
    required this.otherName,
    required this.eventName,
    required this.lastMessage,
    required this.updatedAt,
    this.posterUrl,
    this.unreadCount = 0,
    this.isUnread = false,
  });
  final String id;
  final String otherName;
  final String eventName;
  final String lastMessage;
  final DateTime updatedAt;
  final String? posterUrl;
  final int unreadCount;
  final bool isUnread;

  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    if (diff.inDays < 7) return '${diff.inDays}h';
    return '${updatedAt.day}/${updatedAt.month}';
  }
}

/// Baris percakapan di Activity → Chats.
/// Tinggi sekitar 80.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    this.onTap,
  });

  final ConversationData conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail poster 56×56
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 56,
                height: 56,
                child: conversation.posterUrl != null
                    ? Image.network(
                        conversation.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback(),
                      )
                    : _fallback(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherName,
                          style: AppTextStyles.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        conversation.timeLabel,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.eventName,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: conversation.isUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: conversation.isUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.surfaceHigh,
        child: const Center(
          child: Icon(Icons.confirmation_number_outlined,
              color: AppColors.primary, size: 20),
        ),
      );
}

// ---------------------------------------------------------------------------
// ChatListingCard
// ---------------------------------------------------------------------------

class ChatListingCard extends StatelessWidget {
  const ChatListingCard({
    super.key,
    required this.eventName,
    required this.priceLabel,
    required this.status,
    this.posterUrl,
    this.onTap,
  });

  final String eventName;
  final String priceLabel;
  final String status;
  final String? posterUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 40,
                height: 56,
                child: posterUrl != null
                    ? Image.network(posterUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback())
                    : _fallback(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eventName,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    priceLabel,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.chipInactive,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                status,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.surfaceHigh,
        child: const Center(
          child: Icon(Icons.confirmation_number_outlined,
              color: AppColors.primary, size: 16),
        ),
      );
}

// ---------------------------------------------------------------------------
// ChatBubble
// ---------------------------------------------------------------------------

enum MessageSendStatus { sent, sending, failed }

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isSelf,
    this.timeLabel,
    this.status = MessageSendStatus.sent,
    this.onRetry,
  });

  final String message;
  final bool isSelf;
  final String? timeLabel;
  final MessageSendStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH, vertical: 2),
      child: Column(
        crossAxisAlignment:
            isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isSelf && status == MessageSendStatus.failed) ...[
                GestureDetector(
                  onTap: onRetry,
                  child: const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.xs, bottom: 4),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.urgent,
                      size: 20,
                    ),
                  ),
                ),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        isSelf ? AppColors.primary : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isSelf ? 16 : 4),
                      bottomRight: Radius.circular(isSelf ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: isSelf
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isSelf && status == MessageSendStatus.sending) ...[
            const SizedBox(height: 4),
            Text(
              'Mengirim…',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ] else if (timeLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              timeLabel!,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ChatInput
// ---------------------------------------------------------------------------

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    this.onSend,
    this.isBlocked = false,
  });

  final void Function(String)? onSend;
  final bool isBlocked;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBlocked) {
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Kamu tidak bisa mengirim pesan di percakapan ini.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: AppSpacing.screenH,
        right: AppSpacing.screenH,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm +
            MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                maxLength: 1000,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  counterText: '',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _hasText ? _send : null,
            child: Icon(
              Icons.send_rounded,
              color:
                  _hasText ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DateSeparator (pemisah tanggal dalam chat)
// ---------------------------------------------------------------------------

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: AppColors.divider, thickness: 1)),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const Expanded(
              child: Divider(color: AppColors.divider, thickness: 1)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QuickReplyChips (saran pesan di chat kosong)
// ---------------------------------------------------------------------------

class QuickReplyChips extends StatelessWidget {
  const QuickReplyChips({
    super.key,
    required this.suggestions,
    this.onTap,
  });

  final List<String> suggestions;
  final void Function(String)? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: suggestions
          .map((s) => GestureDetector(
                onTap: () => onTap?.call(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.chipInactive,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(s,
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// BottomNav
// ---------------------------------------------------------------------------

class DroptixBottomNav extends StatelessWidget {
  const DroptixBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 64,
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: Colors.transparent,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: _NavUnreadIcon(
            icon: Icons.receipt_long_outlined,
            unreadCount: unreadCount,
          ),
          selectedIcon: _NavUnreadIcon(
            icon: Icons.receipt_long_rounded,
            unreadCount: unreadCount,
          ),
          label: 'Activity',
        ),
        const NavigationDestination(
          icon: Icon(Icons.sell_outlined),
          selectedIcon: Icon(Icons.sell_rounded),
          label: 'Sell',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _NavUnreadIcon extends StatelessWidget {
  const _NavUnreadIcon({required this.icon, required this.unreadCount});

  final IconData icon;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -10,
          top: -6,
          child: UnreadBadge(count: unreadCount),
        ),
      ],
    );
  }
}
