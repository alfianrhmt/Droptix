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

/// Carousel banner bergaya kartu foto full-bleed (portrait/tall card)
/// dengan kartu berikutnya mengintip di sisi kanan dan teks minimalis di bawah.
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
  final PageController _ctrl = PageController(viewportFraction: 0.74);
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
        height: 220,
        child: EmptyState(
          icon: Icons.image_not_supported_outlined,
          message: 'Tidak ada banner tersedia.',
        ),
      );
    }

    return SizedBox(
      height: 248,
      child: PageView.builder(
        controller: _ctrl,
        padEnds: false,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) {
          final item = items[i];
          final isActive = i == _page;
          final isFirst = i == 0;
          final isLast = i == items.length - 1;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: isFirst ? AppSpacing.screenH : 6,
              right: isLast ? AppSpacing.screenH : 6,
              top: isActive ? 0 : 10,
              bottom: isActive ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: () => widget.onTap?.call(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _EditorialBannerCard(item: item),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditorialBannerCard extends StatelessWidget {
  const _EditorialBannerCard({required this.item});
  final BannerItem item;

  @override
  Widget build(BuildContext context) {
    final banner = item.appBanner;
    String? rawImageUrl = item.imageUrl;
    String title = item.eventName;
    String? overline;

    if (banner != null) {
      title = (banner.title as String?)?.isNotEmpty == true
          ? banner.title as String
          : item.eventName;
      overline = (banner.badge as String?)?.isNotEmpty == true
          ? banner.badge as String
          : (banner.subtitle as String?);

      if (banner.type == 'hype_triptych') {
        final posters = banner.posters as List<dynamic>? ?? const [];
        if (posters.isNotEmpty) {
          rawImageUrl = posters.first.posterUrl as String?;
        }
      } else {
        rawImageUrl = banner.imageUrl as String?;
      }
    }

    final resolvedUrl = EventPoster.resolveUrl(rawImageUrl);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Foto full-bleed
        if (resolvedUrl != null)
          Image.network(
            resolvedUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackBackground(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _fallbackBackground(),
          )
        else
          _fallbackBackground(),

        // Gradasi gelap lembut dari bawah ke atas agar teks terbaca tajam
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
              colors: [
                Colors.black.withAlpha(25),
                Colors.black.withAlpha(60),
                Colors.black.withAlpha(235),
              ],
            ),
          ),
        ),

        // Ikon aksi bulat di pojok kanan atas (gaya referensi)
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(115),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.north_east_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),

        // Teks minimalis di pojok kiri bawah
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overline != null && overline.isNotEmpty) ...[
                Text(
                  overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.glowEnd,
            AppColors.glowMid,
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.confirmation_number_outlined,
          size: 42,
          color: AppColors.primary.withAlpha(90),
        ),
      ),
    );
  }
}
