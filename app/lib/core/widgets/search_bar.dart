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
    this.onChanged,
    this.focusNode,
    this.suffixIcon,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
    this.hintText = 'Cari artis, event, tempat…',
    this.autofocus = false,
    this.readOnly = false,
  });

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final Widget? leading;
  final EdgeInsetsGeometry padding;
  final String hintText;
  final bool autofocus;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: onTap,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofocus: autofocus,
          readOnly: readOnly,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            prefixIcon: leading ??
                const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 22),
            suffixIcon: suffixIcon,
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

