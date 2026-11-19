import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'empty_state.dart';
import 'event_poster.dart';

/// Model data banner.
class BannerItem {
  const BannerItem({
    required this.imageUrl,
    required this.eventName,
    this.keyword,
  });
  final String imageUrl;
  final String eventName;
  final String? keyword;
}

/// Carousel banner 2:1, radius 20, banner berikutnya mengintip.
/// Maks. 5 banner.
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
  final PageController _ctrl = PageController(viewportFraction: 0.88);
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
        height: 180,
        child: EmptyState(
          icon: Icons.image_not_supported_outlined,
          message: 'Tidak ada banner tersedia.',
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => widget.onTap?.call(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: _BannerImage(imageUrl: item.imageUrl),
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
              width: _page == i ? 16 : 6,
              height: 6,
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

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.imageUrl});
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
