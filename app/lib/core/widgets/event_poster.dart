import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/api_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Poster event berasio 2:3 dengan poster cadangan otomatis bila gambar kosong atau gagal dimuat.
class EventPoster extends StatelessWidget {
  const EventPoster({
    super.key,
    required this.title,
    this.posterUrl,
    this.previewBytes,
    this.categorySlug,
    this.width,
    this.borderRadius = AppRadius.md,
  });

  final String title;
  final String? posterUrl;
  final Uint8List? previewBytes;
  final String? categorySlug;
  final double? width;
  final double borderRadius;

  static IconData iconForCategory(String? slug) {
    return switch (slug) {
      'konser-festival' => Icons.music_note_rounded,
      'bioskop' => Icons.movie_outlined,
      'olahraga' => Icons.sports_soccer_rounded,
      'wisata' => Icons.landscape_outlined,
      _ => Icons.confirmation_number_outlined,
    };
  }

  static String? resolveUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${ApiConfig.hostUrl}$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveUrl(posterUrl);

    Widget content;
    if (previewBytes != null) {
      content = Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _FallbackPoster(
          title: title,
          categorySlug: categorySlug,
        ),
      );
    } else if (resolvedUrl != null) {
      content = Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _FallbackPoster(
          title: title,
          categorySlug: categorySlug,
        ),
      );
    } else {
      content = _FallbackPoster(
        title: title,
        categorySlug: categorySlug,
      );
    }

    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: content,
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: poster);
    }
    return poster;
  }
}

class _FallbackPoster extends StatelessWidget {
  const _FallbackPoster({
    required this.title,
    this.categorySlug,
  });

  final String title;
  final String? categorySlug;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.glowEnd, AppColors.surfaceHigh],
        ),
        border: Border.all(
          color: AppColors.outlineTeal.withValues(alpha: 0.4),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 72 || constraints.maxWidth < 56;
          if (isCompact) {
            return Center(
              child: Icon(
                EventPoster.iconForCategory(categorySlug),
                color: AppColors.primary,
                size: 20,
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  EventPoster.iconForCategory(categorySlug),
                  color: AppColors.primary,
                  size: 26,
                ),
                const SizedBox(height: AppSpacing.xs),
                Flexible(
                  child: Text(
                    title.trim().isEmpty ? 'Poster Event' : title.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
