import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'badges.dart';

/// Model data untuk PosterCard dan ListingRow.
class ListingData {
  const ListingData({
    required this.id,
    required this.eventName,
    required this.venueName,
    required this.city,
    required this.eventDate,
    required this.pricePerTicket,
    required this.ticketCount,
    this.posterUrl,
    this.distanceKm,
    this.type,
    this.isSaved = false,
    this.discountPercent,
  });

  final String id;
  final String eventName;
  final String venueName;
  final String city;
  final DateTime eventDate;
  final int pricePerTicket;
  final int ticketCount;
  final String? posterUrl;
  final double? distanceKm;
  final TicketType? type;
  final bool isSaved;
  final int? discountPercent;

  String get formattedPrice {
    final formatted = pricePerTicket.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'Rp $formatted';
  }

  String get distanceLabel {
    if (distanceKm == null) return '';
    return '${distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

// ---------------------------------------------------------------------------
// PosterCard (carousel "Dekat Kamu")
// ---------------------------------------------------------------------------

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.listing,
    this.onTap,
  });

  final ListingData listing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster 2:3
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  children: [
                    _PosterImage(
                      posterUrl: listing.posterUrl,
                      eventName: listing.eventName,
                    ),
                    // Chip semi-transparan bawah
                    Positioned(
                      bottom: 8,
                      left: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140), // 55%
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_number_outlined,
                                color: AppColors.primary, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${listing.ticketCount} tiket',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              listing.eventName.toUpperCase(),
              style: AppTextStyles.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              [listing.venueName, listing.distanceLabel]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              listing.formattedPrice,
              style: AppTextStyles.label,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ListingRow (pencarian, kategori, Activity)
// ---------------------------------------------------------------------------

class ListingRow extends StatelessWidget {
  const ListingRow({
    super.key,
    required this.listing,
    this.onTap,
    this.onFavoriteTap,
  });

  final ListingData listing;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail 72×72
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _PosterImage(
                  posterUrl: listing.posterUrl,
                  eventName: listing.eventName,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Info tengah
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.eventName,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      listing.venueName,
                      listing.city,
                      if (listing.distanceKm != null) listing.distanceLabel,
                    ].join(' · '),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 12, color: AppColors.urgent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: CountdownBadge(eventDate: listing.eventDate),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_outlined,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${listing.ticketCount} tiket',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Harga + favorit
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(listing.formattedPrice, style: AppTextStyles.label),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onFavoriteTap,
                  child: Icon(
                    listing.isSaved
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: listing.isSaved
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared poster image widget
// ---------------------------------------------------------------------------

class _PosterImage extends StatelessWidget {
  const _PosterImage({this.posterUrl, required this.eventName});

  final String? posterUrl;
  final String eventName;

  @override
  Widget build(BuildContext context) {
    if (posterUrl == null || posterUrl!.isEmpty) return _fallback();
    return Image.network(
      posterUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
      loadingBuilder: (_, child, prog) =>
          prog == null ? child : _skeleton(),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.surfaceHigh,
        child: const Center(
          child: Icon(Icons.confirmation_number_outlined,
              color: AppColors.primary, size: 24),
        ),
      );

  Widget _skeleton() => Container(color: AppColors.surfaceHigh);
}

