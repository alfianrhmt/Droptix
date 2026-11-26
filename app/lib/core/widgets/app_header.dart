import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'badges.dart';

/// Header statis — wordmark "Droptix" di kiri, pil lokasi & tombol notifikasi di kanan.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.city = 'Surabaya',
    this.onLocationTap,
    this.onNotificationTap,
    this.unreadNotificationsCount = 0,
  });

  final String city;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationTap;
  final int unreadNotificationsCount;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Row(
          children: [
            // Wordmark
            Text(
              'Droptix',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
                fontSize: 18,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Pil lokasi ramping
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onLocationTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (onNotificationTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onNotificationTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textPrimary,
                          size: 23,
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            top: -4,
                            right: -5,
                            child: UnreadBadge(count: unreadNotificationsCount),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

