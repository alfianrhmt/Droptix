import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Dua tombol pintasan jenis resell (Limited & Last-Minute) yang ramping
/// untuk diletakkan di bagian atas halaman Home.
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
            child: _CompactResellPill(
              title: 'Limited',
              icon: Icons.confirmation_number_outlined,
              accentColor: AppColors.primary,
              onTap: onLimitedTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CompactResellPill(
              title: 'Last-Minute',
              icon: Icons.schedule_rounded,
              accentColor: AppColors.urgent,
              onTap: onLastMinuteTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactResellPill extends StatelessWidget {
  const _CompactResellPill({
    required this.title,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(24),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: accentColor, size: 15),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.label.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textSecondary.withAlpha(180),
            ),
          ],
        ),
      ),
    );
  }
}
