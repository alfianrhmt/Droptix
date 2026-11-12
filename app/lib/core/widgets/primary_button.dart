import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Tombol utama (pil penuh, tinggi 52, isi primary, teks onPrimary).
/// [variant] == [ButtonVariant.secondary] → outline outlineTeal.
enum ButtonVariant { primary, secondary }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == ButtonVariant.primary;

    Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isPrimary ? AppColors.onPrimary : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: AppTextStyles.label.copyWith(
                color: isPrimary ? AppColors.onPrimary : AppColors.primary,
              )),
            ],
          );

    if (isPrimary) {
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withAlpha(80),
            shape: const StadiumBorder(),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outlineTeal),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
        child: child,
      ),
    );
  }
}

