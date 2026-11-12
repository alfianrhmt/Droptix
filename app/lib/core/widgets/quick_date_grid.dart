import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Grid 2×2: Hari ini, Besok, Akhir pekan, Lihat semua.
/// Tombol outline, tinggi 52, radius 16.
class QuickDateGrid extends StatelessWidget {
  const QuickDateGrid({
    super.key,
    this.onTodayTap,
    this.onTomorrowTap,
    this.onWeekendTap,
    this.onAllTap,
  });

  final VoidCallback? onTodayTap;
  final VoidCallback? onTomorrowTap;
  final VoidCallback? onWeekendTap;
  final VoidCallback? onAllTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Hari ini', onTodayTap),
      ('Besok', onTomorrowTap),
      ('Akhir pekan', onWeekendTap),
      ('Lihat semua', onAllTap),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        children: items
            .map((e) => _DateButton(label: e.$1, onTap: e.$2))
            .toList(),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.outlineTeal.withAlpha(153), // 60%
              width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

