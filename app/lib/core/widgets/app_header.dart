import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Header statis — wordmark "Droptix" di kiri, pil lokasi di kanan.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.city = 'Surabaya',
    this.onLocationTap,
  });

  final String city;
  final VoidCallback? onLocationTap;

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
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Pil lokasi
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onLocationTap,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

