import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Dua kotak berdampingan: Limited dan Last-Minute.
/// Tinggi 72, radius 16, border outlineTeal, isi iconButtonFill.
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
            child: _Tile(
              title: 'Limited',
              subtitle: 'Tiket langka, cepat habis',
              onTap: onLimitedTap,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Tile(
              title: 'Last-Minute',
              subtitle: 'Lebih murah, acara segera mulai',
              onTap: onLastMinuteTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.iconButtonFill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineTeal, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: AppTextStyles.label),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

