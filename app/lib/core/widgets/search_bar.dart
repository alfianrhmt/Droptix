import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Search bar lebar penuh, tinggi 48, surfaceHigh, radius 16.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.onTap,
    this.controller,
    this.onSubmitted,
    this.autofocus = false,
    this.readOnly = false,
  });

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: controller,
          onTap: onTap,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          readOnly: readOnly,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Cari artis, event, tempat…',
            hintStyle:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 22),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.outlineTeal, width: 1),
            ),
          ),
        ),
      ),
    );
  }
}

