import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../core/location/location_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/event_poster.dart';
import '../../core/widgets/primary_button.dart';
import '../listings/listing_detail_screen.dart';
import '../listings/listing_models.dart';
import '../sell/sell_screen.dart';
import 'event_models.dart';
import 'event_repository.dart';

/// Halaman Khusus Event (Event Hub ala TicketSwap) di Droptix.
/// Mengumpulkan seluruh tiket yang dijual oleh berbagai penjual untuk satu event,
/// dilengkapi filter urutan, pemantauan notifikasi tiket baru (Ticket Alert),
/// serta tombol jual tiket acara ini.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initialEvent,
    this.eventRepository,
  });

  final int eventId;
  final EventItem? initialEvent;
  final EventRepository? eventRepository;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late EventRepository _eventRepo;
  bool _repoInitialized = false;

  EventDetailModel? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedSort = 'termurah'; // 'termurah' | 'terdekat' | 'segera' | 'terbaru'
  bool _isTogglingAlert = false;

  static const _sortOptions = [
    {'key': 'termurah', 'label': 'Termurah'},
    {'key': 'terdekat', 'label': 'Terdekat'},
    {'key': 'segera', 'label': 'Segera Tayang'},
    {'key': 'terbaru', 'label': 'Terbaru'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final client = AuthScope.maybeOf(context)?.repository.client ??
          ApiClient(tokenStorage: TokenStorage());
      _eventRepo = widget.eventRepository ?? EventRepository(client);
      _repoInitialized = true;
      _fetchEventDetail();
    }
  }

  Future<void> _fetchEventDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final location = LocationScope.maybeOf(context);
      final detail = await _eventRepo.getEventDetail(
        widget.eventId,
        sort: _selectedSort,
        lat: location?.lat,
        lng: location?.lng,
      );

      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat informasi event: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _toggleAlert() async {
    final detail = _detail;
    if (detail == null || _isTogglingAlert) return;

    final auth = AuthScope.of(context);
    auth.requireAuthAction(context, () async {
      setState(() => _isTogglingAlert = true);
      try {
        final nextActive = await _eventRepo.toggleEventAlert(widget.eventId);
        if (mounted) {
          setState(() {
            _detail = _detail?.copyWith(isAlertActive: nextActive);
            _isTogglingAlert = false;
          });

          final message = nextActive
              ? 'Notifikasi diaktifkan. Anda akan diberitahu saat ada tiket baru.'
              : 'Notifikasi tiket untuk event ini dimatikan.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.surfaceHigh,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isTogglingAlert = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui notifikasi: $e'),
              backgroundColor: AppColors.urgent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _onSortChanged(String sortKey) {
    if (_selectedSort == sortKey) return;
    setState(() {
      _selectedSort = sortKey;
    });
    _fetchEventDetail();
  }

  void _goToSell() {
    final detail = _detail;
    final event = detail?.event ?? widget.initialEvent;
    if (event == null) return;

    final auth = AuthScope.of(context);
    auth.requireAuthAction(context, () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SellScreen(initialEvent: event),
        ),
      );
    });
  }

  String _formatPrice(int harga) {
    final s = harga.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $s';
  }

  String _formatDate(DateTime dt) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final d = days[dt.weekday - 1];
    final m = months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d, ${dt.day} $m · $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceHigh,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          title: Text(
            _detail?.event.nama ?? widget.initialEvent?.nama ?? 'Detail Event',
            style: AppTextStyles.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _detail == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.urgent, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Terjadi Kendala', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: _fetchEventDetail,
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final event = detail.event;
    final stats = detail.stats;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchEventDetail,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          // 1. Header Ringkasan Event (Poster + Info)
          _buildEventHeader(event),
          const SizedBox(height: AppSpacing.md),

          // 2. Kotak Statistik (Tiket Tersedia, Rentang Harga, Penjual)
          _buildStatsCard(stats),
          const SizedBox(height: AppSpacing.md),

          // 3. Action Bar: Pantau Event & Jual Tiket Ini
          _buildActionBar(detail),
          const SizedBox(height: AppSpacing.lg),

          // 4. Section Baris Urutan (Filter Bar)
          _buildFilterBar(detail),
          const SizedBox(height: AppSpacing.md),

          // 5. Daftar Tiket Yang Dijual
          if (detail.listings.isEmpty)
            _buildEmptyListings()
          else
            ...detail.listings.map((l) => _buildListingCard(l)),
        ],
      ),
    );
  }

  Widget _buildEventHeader(EventItem event) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster 2:3
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 90,
              height: 135,
              child: EventPoster(
                title: event.nama,
                posterUrl: event.posterUrl,
                categorySlug: event.category.slug,
                width: 90,
                borderRadius: AppRadius.md,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Detail Teks Event
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    event.category.nama,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Nama Event
                Text(
                  event.nama,
                  style: AppTextStyles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),

                // Lokasi / Venue
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.venue != null
                            ? '${event.venue!.nama}, ${event.venue!.kota}'
                            : (event.category.slug == 'bioskop'
                                ? 'Bioskop Multi-Lokasi'
                                : 'Indonesia'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Tanggal
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.tanggal != null
                            ? _formatDate(event.tanggal!)
                            : (event.tanggalOpsi.isNotEmpty
                                ? '${event.tanggalOpsi.length} Jadwal Penayangan'
                                : 'Segera Hadir'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(EventStatsModel stats) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // 1. Tiket Tersedia
          Expanded(
            child: Column(
              children: [
                Text(
                  '${stats.availableTicketsCount}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tiket Tersedia',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: 1,
            color: AppColors.divider,
          ),

          // 2. Harga Termurah
          Expanded(
            child: Column(
              children: [
                Text(
                  stats.minPrice != null
                      ? _formatPrice(stats.minPrice!)
                      : '-',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Harga Mulai',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: 1,
            color: AppColors.divider,
          ),

          // 3. Penjual Aktif
          Expanded(
            child: Column(
              children: [
                Text(
                  '${stats.sellersCount}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Penjual Aktif',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(EventDetailModel detail) {
    final isAlert = detail.isAlertActive;

    return Row(
      children: [
        // Tombol Pantau / Ticket Alert
        Expanded(
          flex: 5,
          child: OutlinedButton.icon(
            onPressed: _isTogglingAlert ? null : _toggleAlert,
            icon: Icon(
              isAlert
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: 18,
              color: isAlert ? AppColors.primary : AppColors.textPrimary,
            ),
            label: Text(
              isAlert ? 'Dipantau' : 'Pantau Tiket',
              style: AppTextStyles.label.copyWith(
                color: isAlert ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: isAlert ? AppColors.primary : AppColors.divider,
                width: 1.5,
              ),
              backgroundColor: isAlert
                  ? AppColors.primary.withAlpha(20)
                  : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Tombol Jual Tiket Acara Ini
        Expanded(
          flex: 5,
          child: ElevatedButton.icon(
            onPressed: _goToSell,
            icon: const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: AppColors.onPrimary),
            label: Text(
              'Jual Tiket',
              style: AppTextStyles.label.copyWith(color: AppColors.onPrimary),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(EventDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Tiket Tersedia (${detail.listings.length})',
                style: AppTextStyles.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Chips horizontal pilihan urutan
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _sortOptions.map((opt) {
              final isSelected = _selectedSort == opt['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  onSelected: (_) => _onSortChanged(opt['key']!),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListingCard(ListingItem listing) {
    final sellerName = listing.seller?.username != null
        ? '@${listing.seller!.username}'
        : (listing.seller?.nama ?? 'Penjual');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(
                  listingId: listing.id,
                  initialItem: listing,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Atas: Waktu & Venue
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: AppColors.urgent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDate(listing.waktuAcara),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.urgent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TypeBadge(
                      type: listing.jenis == 'limited'
                          ? TicketType.limited
                          : TicketType.lastMinute,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Baris Venue
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${listing.venueNama}, ${listing.kota}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (listing.jarakKm != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${listing.jarakKm} km',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Seksi / Studio & Nomor Kursi
                if (listing.seksi != null || listing.noKursi != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.event_seat_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            if (listing.seksi != null) listing.seksi!,
                            if (listing.noKursi != null)
                              'Kursi ${listing.noKursi!}',
                          ].join(' · '),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                const Divider(color: AppColors.divider, height: 16),

                // Baris Bawah: Penjual & Harga
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Info Penjual & Stok
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellerName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sisa ${listing.jumlahTersedia} tiket',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Harga & Diskon
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (listing.hargaAsli != null &&
                            listing.hargaAsli! > listing.harga) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatPrice(listing.hargaAsli!),
                                style: AppTextStyles.caption.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (listing.diskonPersen != null) ...[
                                const SizedBox(width: 4),
                                DiscountBadge(percent: listing.diskonPersen!),
                              ],
                            ],
                          ),
                        ],
                        Text(
                          _formatPrice(listing.harga),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyListings() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum Ada Tiket yang Dijual',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Belum ada pengguna yang menjual tiket untuk acara ini. '
            'Aktifkan notifikasi untuk mendapat info saat tiket masuk, '
            'atau jadilah yang pertama menjual tiketmu di sini!',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Jual Tiket Acara Ini',
            icon: Icons.add_rounded,
            onPressed: _goToSell,
          ),
        ],
      ),
    );
  }
}
