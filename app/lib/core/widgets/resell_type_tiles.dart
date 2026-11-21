import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Dua kartu spotlight: Limited dan Last-Minute.
/// Didesain minimalis dan modern (tanpa emoji), selaras dengan tema gelap Droptix.
class ResellTypeTiles extends StatelessWidget {
  const ResellTypeTiles({
    super.key,
    this.onLimitedTap,
    this.onLastMinuteTap,
  });

  final VoidCallback? onLimitedTap;
  final VoidCallback? onLastMinuteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          Expanded(
            child: _SpotlightTile(
              title: 'Limited',
              subtitle: 'Tiket langka',
              icon: Icons.stars_rounded,
              accentColor: AppColors.primary,
              onTap: onLimitedTap,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _SpotlightTile(
              title: 'Last-Minute',
              subtitle: 'Acara segera mulai',
              icon: Icons.bolt_rounded,
              accentColor: AppColors.urgent,
              onTap: onLastMinuteTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightTile extends StatelessWidget {
  const _SpotlightTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.white.withAlpha(16),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.textSecondary.withAlpha(140),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
