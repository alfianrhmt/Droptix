import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Data model kategori.
class CategoryItem {
  const CategoryItem({
    required this.label,
    required this.icon,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

/// 4 Kategori bawaan: Konser, Bioskop, Olahraga, Lainnya.
const List<CategoryItem> defaultCategories = [
  CategoryItem(label: 'Konser', icon: Icons.music_note_rounded),
  CategoryItem(label: 'Bioskop', icon: Icons.movie_rounded),
  CategoryItem(label: 'Olahraga', icon: Icons.sports_soccer_rounded),
  CategoryItem(label: 'Lainnya', icon: Icons.more_horiz_rounded),
];

/// Baris 4 kategori statis, terbagi rata secara simetris di layar dan sejajar 100%.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    this.categories = defaultCategories,
    this.onTap,
  });

  final List<CategoryItem> categories;
  final void Function(CategoryItem)? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _CategoryTile(
                category: categories[i],
                onTap: () =>
                    (categories[i].onTap ?? () => onTap?.call(categories[i]))(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final CategoryItem category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: Colors.white.withAlpha(16),
                width: 1,
              ),
            ),
            child: Icon(category.icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            category.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
