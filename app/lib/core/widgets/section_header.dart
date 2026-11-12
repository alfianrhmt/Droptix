import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Judul section + tautan "Lihat semua" di kanan.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.showSeeAll = true,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final bool showSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.titleMedium),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'Lihat semua',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

