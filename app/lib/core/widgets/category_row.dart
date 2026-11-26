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

/// 5 Kategori bawaan: Konser, Bioskop, Olahraga, Voucher, Lainnya.
const List<CategoryItem> defaultCategories = [
  CategoryItem(label: 'Konser', icon: Icons.music_note_rounded),
  CategoryItem(label: 'Bioskop', icon: Icons.movie_rounded),
  CategoryItem(label: 'Olahraga', icon: Icons.sports_soccer_rounded),
  CategoryItem(label: 'Voucher', icon: Icons.local_offer_rounded),
  CategoryItem(label: 'Lainnya', icon: Icons.more_horiz_rounded),
];

/// Baris kategori lingkaran bulat minimalis di bawah tombol Limited & Last-Minute.
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
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _CategoryCircleTile(
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

class _CategoryCircleTile extends StatelessWidget {
  const _CategoryCircleTile({required this.category, required this.onTap});

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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.divider,
                width: 0.8,
              ),
            ),
            child: Icon(
              category.icon,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            category.label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 11,
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
