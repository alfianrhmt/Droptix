import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Kotak statistik 3 kolom: angka + label.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.stats,
  });

  final List<StatItem> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: stats
                .asMap()
                .entries
                .map((e) => [
                      Expanded(child: _StatColumn(item: e.value)),
                      if (e.key < stats.length - 1)
                        const VerticalDivider(
                          color: AppColors.divider,
                          width: 1,
                          thickness: 1,
                        ),
                    ])
                .expand((e) => e)
                .toList(),
          ),
        ),
      ),
    );
  }
}

class StatItem {
  const StatItem({required this.value, required this.label});
  final String value;
  final String label;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.item});
  final StatItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Text(item.value, style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

