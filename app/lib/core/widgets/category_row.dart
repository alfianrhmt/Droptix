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

/// Kategori bawaan sesuai DESIGN.md.
const List<CategoryItem> defaultCategories = [
  CategoryItem(label: 'Konser & Festival', icon: Icons.music_note_rounded),
  CategoryItem(label: 'Bioskop', icon: Icons.movie_rounded),
  CategoryItem(label: 'Olahraga', icon: Icons.sports_soccer_rounded),
  CategoryItem(label: 'Wisata', icon: Icons.landscape_rounded),
  CategoryItem(label: 'Hiburan Lain', icon: Icons.theater_comedy_rounded),
];

/// Baris horizontal kategori, kotak 64×64.
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            _CategoryTile(
              category: categories[i],
              onTap: () =>
                  (categories[i].onTap ?? () => onTap?.call(categories[i]))(),
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
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.iconButtonFill,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineTeal, width: 1),
              ),
              child: Icon(category.icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              category.label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
