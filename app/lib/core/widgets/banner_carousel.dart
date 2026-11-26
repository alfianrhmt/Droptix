import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'empty_state.dart';
import 'event_poster.dart';

/// Model data banner.
class BannerItem {
  const BannerItem({
    required this.imageUrl,
    required this.eventName,
    this.keyword,
    this.appBanner,
  });
  final String imageUrl;
  final String eventName;
  final String? keyword;
  final dynamic appBanner;
}

/// Carousel banner modern Droptix (editorial & promosi).
/// Menampilkan banner promosi dengan teks, badge, tombol CTA, dan triptych poster.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.items,
    this.onTap,
  });

  final List<BannerItem> items;
  final void Function(BannerItem)? onTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.90);
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(5).toList();
    if (items.isEmpty) {
      return const SizedBox(
        height: 175,
        child: EmptyState(
          icon: Icons.image_not_supported_outlined,
          message: 'Tidak ada banner tersedia.',
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: GestureDetector(
                  onTap: () => widget.onTap?.call(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: _BannerCard(item: item),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page == i ? 18 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: _page == i ? AppColors.primary : AppColors.chipInactive,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.item});
  final BannerItem item;

  @override
  Widget build(BuildContext context) {
    final banner = item.appBanner;
    if (banner != null) {
      if (banner.type == 'hype_triptych') {
        return _HypeTriptychCard(banner: banner);
      }
      return _StandardEditorialCard(banner: banner);
    }

    // Fallback bila hanya menyediakan imageUrl & eventName biasa
    return _LegacyBannerImage(imageUrl: item.imageUrl);
  }
}

class _StandardEditorialCard extends StatelessWidget {
  const _StandardEditorialCard({required this.banner});
  final dynamic banner;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = EventPoster.resolveUrl(banner.imageUrl as String?);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (resolvedUrl != null)
            Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _solidBackground(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _solidBackground(),
            )
          else
            _solidBackground(),

          // Dark Gradient Overlay untuk memastikan teks terbaca jelas
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withAlpha(225),
                  Colors.black.withAlpha(170),
                  Colors.black.withAlpha(80),
                ],
              ),
            ),
          ),

          // Konten Teks & Tombol
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (banner.badge != null &&
                    (banner.badge as String).isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      banner.badge as String,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  banner.title as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                if (banner.subtitle != null &&
                    (banner.subtitle as String).isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    banner.subtitle as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withAlpha(185),
                    ),
                  ),
                ],
                const Spacer(),
                if (banner.ctaLabel != null &&
                    (banner.ctaLabel as String).isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          banner.ctaLabel as String,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: AppColors.onPrimary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _solidBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
      ),
    );
  }
}

class _HypeTriptychCard extends StatelessWidget {
  const _HypeTriptychCard({required this.banner});
  final dynamic banner;

  @override
  Widget build(BuildContext context) {
    final rawPosters = banner.posters as List<dynamic>? ?? const [];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E24), Color(0xFF121216)],
        ),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Row(
        children: [
          // Kolom Kiri: Teks & CTA
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.urgent.withAlpha(45),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.urgent.withAlpha(120),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      banner.badge as String? ?? '🔥 SEDANG RAMAI',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.urgent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    banner.title as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  if (banner.subtitle != null &&
                      (banner.subtitle as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          banner.ctaLabel as String? ?? 'Lihat Semua Event',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Kolom Kanan: 3 Poster Portrait berdampingan utuh
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _TriptychPosters(posters: rawPosters),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriptychPosters extends StatelessWidget {
  const _TriptychPosters({required this.posters});
  final List<dynamic> posters;

  @override
  Widget build(BuildContext context) {
    final posterList = posters.take(3).toList();

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _SingleMiniPoster(
              posterUrl: i < posterList.length ? posterList[i].posterUrl : null,
              index: i,
            ),
          ],
        ],
      ),
    );
  }
}

class _SingleMiniPoster extends StatelessWidget {
  const _SingleMiniPoster({required this.posterUrl, required this.index});
  final String? posterUrl;
  final int index;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = EventPoster.resolveUrl(posterUrl);

    return Container(
      width: 35,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(30),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: resolvedUrl != null
            ? Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackIcon(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _skeleton(),
              )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() => Container(
        color: AppColors.surfaceHigh,
        child: const Center(
          child: Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.primary,
            size: 16,
          ),
        ),
      );

  Widget _skeleton() => Container(color: AppColors.surfaceHigh);
}

class _LegacyBannerImage extends StatelessWidget {
  const _LegacyBannerImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = EventPoster.resolveUrl(imageUrl);
    return AspectRatio(
      aspectRatio: 2 / 1,
      child: resolvedUrl == null
          ? _fallback()
          : Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _skeleton(),
            ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.surfaceHigh,
        child: const Center(
          child: Icon(Icons.confirmation_number_outlined,
              color: AppColors.primary, size: 40),
        ),
      );

  Widget _skeleton() => Container(color: AppColors.surfaceHigh);
}
