import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

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
  CategoryItem(label: 'Konser & Festival', icon: Icons.music_note_rounded),
  CategoryItem(label: 'Bioskop', icon: Icons.movie_rounded),
  CategoryItem(label: 'Olahraga', icon: Icons.sports_soccer_rounded),
  CategoryItem(label: 'Lainnya', icon: Icons.more_horiz_rounded),
];

/// Baris 4 kategori statis (non-scrollable), terbagi rata secara simetris di layar.
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.iconButtonFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.outlineTeal.withAlpha(120),
                width: 1,
              ),
            ),
            child: Icon(category.icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: Text(
              category.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
