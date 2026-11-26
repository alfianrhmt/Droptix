import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'badges.dart';
import 'event_poster.dart';

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
              child: Builder(
                builder: (context) {
                  final resolved = EventPoster.resolveUrl(conversation.posterUrl);
                  return SizedBox(
                    width: 56,
                    height: 56,
                    child: resolved != null
                        ? Image.network(
                            resolved,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallback(),
                          )
                        : _fallback(),
                  );
                },
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
              child: Builder(
                builder: (context) {
                  final resolved = EventPoster.resolveUrl(posterUrl);
                  return SizedBox(
                    width: 40,
                    height: 56,
                    child: resolved != null
                        ? Image.network(
                            resolved,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallback(),
                          )
                        : _fallback(),
                  );
                },
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
                color: status == 'Tersedia'
                    ? AppColors.primary.withAlpha(25)
                    : (status == 'Kedaluwarsa'
                        ? AppColors.urgent.withAlpha(25)
                        : AppColors.chipInactive),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                status,
                style: AppTextStyles.caption.copyWith(
                  color: status == 'Tersedia'
                      ? AppColors.primary
                      : (status == 'Kedaluwarsa'
                          ? AppColors.urgent
                          : AppColors.textSecondary),
                  fontWeight: FontWeight.w600,
                ),
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
    this.onLongPress,
  });

  final String message;
  final bool isSelf;
  final String? timeLabel;
  final MessageSendStatus status;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;

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
                child: GestureDetector(
                  onLongPress: onLongPress,
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
    _ctrl.clear();
    widget.onSend?.call(text);
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

  static const _items = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    (
      label: 'Saved',
      icon: Icons.bookmark_outline_rounded,
      activeIcon: Icons.bookmark_rounded,
    ),
    (
      label: 'Sell',
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
    ),
    (
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    (
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          6,
          AppSpacing.screenH,
          12,
        ),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF132A2E),
                Color(0xFF0C1D20),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.primary.withAlpha(32),
              width: 1,
            ),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isSelected = currentIndex == i;
              final isCenter = i == 2;
              final iconData = isSelected ? item.activeIcon : item.icon;

              Widget content;
              if (isCenter) {
                content = AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withAlpha(48),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                    size: 22,
                  ),
                );
              } else {
                final iconColor = isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withAlpha(190);
                final iconWidget = i == 3
                    ? _NavUnreadIcon(
                        icon: iconData,
                        unreadCount: unreadCount,
                        color: iconColor,
                      )
                    : Icon(iconData, color: iconColor, size: 22);

                content = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: isSelected ? 4 : 0,
                      height: isSelected ? 4 : 0,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                );
              }

              return Expanded(
                child: Semantics(
                  label: item.label,
                  selected: isSelected,
                  button: true,
                  child: Tooltip(
                    message: item.label,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Center(child: content),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavUnreadIcon extends StatelessWidget {
  const _NavUnreadIcon({
    required this.icon,
    required this.unreadCount,
    this.color,
  });

  final IconData icon;
  final int unreadCount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return Icon(icon, color: color, size: 23);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: 23),
        Positioned(
          right: -10,
          top: -6,
          child: UnreadBadge(count: unreadCount),
        ),
      ],
    );
  }
}
