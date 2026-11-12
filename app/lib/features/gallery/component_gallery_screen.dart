import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'sample_data.dart';

/// Layar Component Gallery untuk memverifikasi semua komponen bersama
/// dengan data contoh sebelum membuat layar fitur satu per satu.
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  int _navIndex = 0;
  final Set<String> _activeFilters = {'Jenis', 'Tersedia'};
  final Set<String> _savedIds = {'lst-1', 'lst-4'};
  String _selectedCity = 'Surabaya';

  void _toggleFilter(String label) {
    setState(() {
      if (_activeFilters.contains(label)) {
        _activeFilters.remove(label);
      } else {
        _activeFilters.add(label);
      }
    });
  }

  void _toggleSaved(String id) {
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listings = GallerySampleData.listings
        .map((item) => ListingData(
              id: item.id,
              eventName: item.eventName,
              venueName: item.venueName,
              city: item.city,
              eventDate: item.eventDate,
              pricePerTicket: item.pricePerTicket,
              ticketCount: item.ticketCount,
              posterUrl: item.posterUrl,
              distanceKm: item.distanceKm,
              type: item.type,
              isSaved: _savedIds.contains(item.id),
              discountPercent: item.discountPercent,
            ))
        .toList();

    final content = SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                AppHeader(
                  city: _selectedCity,
                  onLocationTap: () => setState(() {
                    _selectedCity =
                        _selectedCity == 'Surabaya' ? 'Jakarta' : 'Surabaya';
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppSearchBar(readOnly: true),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('BannerCarousel'),
                BannerCarousel(items: GallerySampleData.banners),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('ResellTypeTiles'),
                const ResellTypeTiles(),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('QuickDateGrid'),
                const QuickDateGrid(),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('CategoryRow'),
                const CategoryRow(),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Dekat Kamu'),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.md),
                        PosterCard(listing: listings[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('FilterChipRow'),
                FilterChipRow(
                  chips: defaultFilterChips(
                    activeLabels: _activeFilters,
                    onTap: _toggleFilter,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Segera Berakhir'),
                const SizedBox(height: AppSpacing.sm),
                for (final item in listings)
                  ListingRow(
                    listing: item,
                    onFavoriteTap: () => _toggleSaved(item.id),
                  ),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('Badge & Chip'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const TypeBadge(type: TicketType.limited),
                      const TypeBadge(type: TicketType.lastMinute),
                      const NeutralChip(label: 'Digital'),
                      const NeutralChip(label: 'CAT 1'),
                      const DiscountBadge(percent: 40),
                      CountdownBadge(eventDate: listings.first.eventDate),
                      const UnreadBadge(count: 3),
                      const UnreadBadge(count: 14),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('StatsCard'),
                const StatsCard(
                  stats: [
                    StatItem(value: '2', label: 'Tersedia'),
                    StatItem(value: '1', label: 'Terjual'),
                    StatItem(value: '8', label: 'Tertarik'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('PrimaryButton'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrimaryButton(
                        label: 'Chat dengan penjual',
                        onPressed: () {},
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Buka di halaman pencarian',
                        variant: ButtonVariant.secondary,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('ConversationRow'),
                for (final conv in GallerySampleData.conversations)
                  ConversationRow(conversation: conv),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('ChatListingCard, Bubble & Input'),
                const ChatListingCard(
                  eventName: 'Nada Senja Live in Surabaya',
                  priceLabel: 'Rp 450.000 / tiket',
                  status: 'Tersedia',
                ),
                const DateSeparator(label: 'Hari ini'),
                const ChatBubble(
                  message: 'Halo kak, tiket festivalnya masih tersedia?',
                  isSelf: false,
                  timeLabel: '19.12',
                ),
                const ChatBubble(
                  message: 'Masih kak, sisa 2 tiket digital.',
                  isSelf: true,
                  timeLabel: '19.14',
                ),
                const ChatBubble(
                  message: 'Otw transfer ya kak',
                  isSelf: true,
                  status: MessageSendStatus.sending,
                ),
                const ChatBubble(
                  message: 'Pesan gagal terkirim',
                  isSelf: true,
                  status: MessageSendStatus.failed,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  child: QuickReplyChips(
                    suggestions: [
                      'Halo, masih tersedia?',
                      'Boleh nego?',
                      'Bisa COD?',
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const ChatInput(),
                const SizedBox(height: AppSpacing.sm),
                const ChatInput(isBlocked: true),
                const SizedBox(height: AppSpacing.lg),

                _GallerySectionLabel('LoadingState, EmptyState & ErrorState'),
                const LoadingState(itemCount: 2),
                EmptyState(
                  icon: Icons.confirmation_number_outlined,
                  message: 'Belum ada tiket untuk pencarian ini.',
                  actionLabel: 'Jual tiketmu',
                  onAction: () {},
                ),
                ErrorState(onRetry: () {}),
              ],
            ),
          ),
        );

    if (widget.embedded) return content;

    return AppBackground(
      child: Scaffold(
        bottomNavigationBar: DroptixBottomNav(
          currentIndex: _navIndex,
          unreadCount: 12,
          onTap: (i) => setState(() => _navIndex = i),
        ),
        body: content,
      ),
    );
  }
}

class _GallerySectionLabel extends StatelessWidget {
  const _GallerySectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenH,
        right: AppSpacing.screenH,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

