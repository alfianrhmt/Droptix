import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Data model chip filter.
class FilterChipData {
  const FilterChipData({
    required this.label,
    this.isActive = false,
    this.hasDropdown = true,
    this.onTap,
  });
  final String label;
  final bool isActive;
  final bool hasDropdown;
  final VoidCallback? onTap;
}

/// Chip filter bawaan sesuai DESIGN.md.
List<FilterChipData> defaultFilterChips({
  Set<String> activeLabels = const {},
  void Function(String)? onTap,
}) {
  final labels = ['Tanggal', 'Urutkan', 'Lokasi', 'Jenis', 'Harga'];
  final all = [
    ...labels.map((l) => FilterChipData(
          label: l,
          isActive: activeLabels.contains(l),
          onTap: () => onTap?.call(l),
        )),
    FilterChipData(
      label: 'Tersedia',
      isActive: activeLabels.contains('Tersedia'),
      hasDropdown: false,
      onTap: () => onTap?.call('Tersedia'),
    ),
  ];
  return all;
}

/// Baris chip yang bisa digeser horizontal.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.chips,
  });

  final List<FilterChipData> chips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => _Chip(chip: chips[i]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});
  final FilterChipData chip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: chip.onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: chip.isActive ? Colors.white : AppColors.chipInactive,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chip.label,
              style: AppTextStyles.label.copyWith(
                color: chip.isActive ? Colors.black : AppColors.textPrimary,
              ),
            ),
            if (chip.hasDropdown) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: chip.isActive ? Colors.black : AppColors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
