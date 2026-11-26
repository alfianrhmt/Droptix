import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../core/location/location_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../chat/chat_socket_service.dart';
import '../events/event_detail_screen.dart';
import '../events/event_models.dart';
import '../events/event_repository.dart';
import '../listings/listing_detail_screen.dart';
import '../listings/listing_models.dart';
import '../listings/listing_repository.dart';
import '../location/location_picker_sheet.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';

/// Halaman Home Droptix bergaya editorial minimalis dark mode.
/// Struktur:
/// 1. AppHeader (wordmark Droptix, pil lokasi ramping, lonceng notifikasi)
/// 2. SearchBar ramping
/// 3. Kartu sorotan ringkas "Segera Berakhir" (jika ada tiket < 24 jam)
/// 4. Baris chip kategori & jenis resell (1 baris horizontal bersih)
/// 5. Section utama "Acara Populer" (kartu event besar dengan poster + "Lihat tiket ->")
/// 6. Section "Tiket Terbaru" (daftar kartu lembut, pagination scroll tanpa batas)
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.listingRepository,
    this.eventRepository,
    this.notificationRepository,
    this.socketService,
    this.onNavigateToTab,
    this.onListingTap,
    this.onSearchTap,
    this.onCategoryTap,
    this.onDateFilterTap,
    this.onResellTypeTap,
  });

  final ListingRepository? listingRepository;
  final EventRepository? eventRepository;
  final NotificationRepository? notificationRepository;
  final ChatSocketService? socketService;
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(ListingItem item)? onListingTap;
  final void Function(String query)? onSearchTap;
  final void Function(String categorySlug, String categoryName)? onCategoryTap;
  final void Function(String dateFilter)? onDateFilterTap;
  final void Function(String resellType)? onResellTypeTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ListingRepository _listingRepo;
  late final EventRepository _eventRepo;
  late final ScrollController _scrollController;
  late final PageController _featuredPageController;
  int _activePopularPage = 0;

  String _city = 'Surabaya';
  double? _lat;
  double? _lng;

  // 1. Acara Populer (Carousel kartu foto full-bleed)
  List<PopularEventItem> _popularEvents = [];
  bool _isLoadingPopular = true;
  String? _popularError;

  // 2. Segera Berakhir (Compact Upcoming Card)
  List<ListingItem> _endingSoonListings = [];
  bool _isLoadingEndingSoon = true;

  // 3. Tiket Terbaru (Pagination)
  final List<ListingItem> _recentListings = [];
  int _recentPage = 1;
  static const int _recentLimit = 20;
  int _recentTotal = 0;
  bool _isLoadingRecentInitial = true;
  bool _isLoadingRecentMore = false;
  String? _recentError;

  bool _isFirstDependencyCheck = true;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(tokenStorage: TokenStorage());
    _listingRepo = widget.listingRepository ?? ListingRepository(apiClient);
    _eventRepo = widget.eventRepository ?? EventRepository(apiClient);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _featuredPageController = PageController(viewportFraction: 0.74);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = LocationScope.maybeOf(context);
    if (loc != null) {
      final locCity = loc.city;
      final locLat = loc.lat;
      final locLng = loc.lng;

      if (_isFirstDependencyCheck) {
        _isFirstDependencyCheck = false;
        _city = locCity;
        _lat = locLat;
        _lng = locLng;
        _fetchHomeData();
      } else if (_city != locCity || _lat != locLat || _lng != locLng) {
        _city = locCity;
        _lat = locLat;
        _lng = locLng;
        _fetchHomeData();
      }
    } else if (_isFirstDependencyCheck) {
      _isFirstDependencyCheck = false;
      _fetchHomeData();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _featuredPageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isLoadingRecentMore &&
        !_isLoadingRecentInitial &&
        _recentListings.length < _recentTotal) {
      _loadMoreRecent();
    }
  }

  Future<void> _fetchHomeData() async {
    await Future.wait([
      _loadPopularEvents(),
      _loadEndingSoonListings(),
      _loadRecentListings(refresh: true),
    ]);
  }

  Future<void> _loadPopularEvents() async {
    setState(() {
      _isLoadingPopular = true;
      _popularError = null;
    });
    try {
      final list = await _eventRepo.getPopularEvents();
      if (mounted) {
        setState(() {
          _popularEvents = list;
          _isLoadingPopular = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _popularEvents = [];
          _popularError = e.toString();
          _isLoadingPopular = false;
        });
      }
    }
  }

  Future<void> _loadEndingSoonListings() async {
    setState(() {
      _isLoadingEndingSoon = true;
    });
    try {
      final result = await _listingRepo.getListings(
        dalamJam: 24,
        sort: 'segera',
        limit: 5,
        tersedia: true,
      );
      if (mounted) {
        setState(() {
          _endingSoonListings = result.items;
          _isLoadingEndingSoon = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _endingSoonListings = [];
          _isLoadingEndingSoon = false;
        });
      }
    }
  }

  Future<void> _loadRecentListings({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoadingRecentInitial = true;
        _recentError = null;
        _recentPage = 1;
      });
    } else {
      setState(() {
        _isLoadingRecentMore = true;
      });
    }

    try {
      final targetPage = refresh ? 1 : _recentPage + 1;
      final result = await _listingRepo.getListings(
        sort: 'terbaru',
        page: targetPage,
        limit: _recentLimit,
        tersedia: true,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _recentListings.clear();
          }
          _recentListings.addAll(result.items);
          _recentTotal = result.total;
          _recentPage = targetPage;
          _isLoadingRecentInitial = false;
          _isLoadingRecentMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecentInitial = false;
          _isLoadingRecentMore = false;
          _recentError = e.toString();
        });
      }
    }
  }

  void _loadMoreRecent() {
    _loadRecentListings(refresh: false);
  }

  // --- Navigasi ---

  void _openSearch({
    String? query,
    String? categorySlug,
    String? categoryName,
    String? jenis,
    String? tanggal,
    String? sort,
    int? maxKm,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          listingRepository: _listingRepo,
          eventRepository: _eventRepo,
          initialQuery: query,
          categorySlug: categorySlug,
          categoryName: categoryName,
          initialJenis: jenis,
          initialTanggal: tanggal,
          initialSort: sort,
          userLat: _lat,
          userLng: _lng,
          initialMaxKm: maxKm,
          onListingTap: widget.onListingTap ?? _handleListingTap,
          onSellPressed: () {
            Navigator.of(context).pop();
            widget.onNavigateToTab?.call(2);
          },
        ),
      ),
    );
  }

  void _handleListingTap(ListingItem item) {
    if (widget.onListingTap != null) {
      widget.onListingTap!(item);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ListingDetailScreen(
            listingId: item.id,
            initialItem: item,
            listingRepository: _listingRepo,
          ),
        ),
      );
    }
  }

  void _openEventDetail(EventItem event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          initialEvent: event,
          eventRepository: _eventRepo,
        ),
      ),
    );
  }

  void _openNotifications() {
    final auth = AuthScope.maybeOf(context);
    void navigate() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsScreen(
            notificationRepository: widget.notificationRepository,
            socketService: widget.socketService,
          ),
        ),
      );
    }

    if (auth != null) {
      auth.requireAuthAction(context, navigate);
    } else {
      navigate();
    }
  }

  String _formatPrice(int harga) {
    final s = harga.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $s';
  }

  String _formatEventDate(EventItem event) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    if (event.tanggal != null) {
      final dt = event.tanggal!.toLocal();
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
    if (event.tanggalOpsi.isNotEmpty) {
      final parsed = DateTime.tryParse(event.tanggalOpsi.first);
      if (parsed != null) {
        return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
      }
    }
    return '';
  }

  // --- Sub-widgets ---

  /// Search bar ramping menyatu dengan background.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: GestureDetector(
        onTap: () => _openSearch(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cari acara, artis, bioskop…',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu ringkas "Segera Berakhir" di atas (gaya "Upcoming Events" di referensi).
  /// Hanya tampil bila ada tiket dalam 24 jam, sehingga layar tetap bersih.
  Widget _buildUpcomingCompactCard() {
    if (_isLoadingEndingSoon || _endingSoonListings.isEmpty) {
      return const SizedBox.shrink();
    }
    final first = _endingSoonListings.first;
    final resolvedPoster = EventPoster.resolveUrl(first.event.posterUrl);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      child: GestureDetector(
        onTap: () => _openSearch(sort: 'segera'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 46,
                  child: resolvedPoster != null
                      ? Image.network(
                          resolvedPoster,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _miniFallback(),
                        )
                      : _miniFallback(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Segera Berakhir',
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${first.event.nama} · ${_formatPrice(first.harga)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1 baris chip horizontal ramping khusus kategori (Konser, Bioskop, Olahraga, Lainnya).
  Widget _buildQuickFilterBar() {
    final chips = <(String label, VoidCallback onTap)>[
      (
        'Konser',
        () {
          if (widget.onCategoryTap != null) {
            widget.onCategoryTap!('konser-festival', 'Konser');
          } else {
            _openSearch(categorySlug: 'konser-festival', categoryName: 'Konser');
          }
        },
      ),
      (
        'Bioskop',
        () {
          if (widget.onCategoryTap != null) {
            widget.onCategoryTap!('bioskop', 'Bioskop');
          } else {
            _openSearch(categorySlug: 'bioskop', categoryName: 'Bioskop');
          }
        },
      ),
      (
        'Olahraga',
        () {
          if (widget.onCategoryTap != null) {
            widget.onCategoryTap!('olahraga', 'Olahraga');
          } else {
            _openSearch(categorySlug: 'olahraga', categoryName: 'Olahraga');
          }
        },
      ),
      (
        'Lainnya',
        () {
          if (widget.onCategoryTap != null) {
            widget.onCategoryTap!('hiburan-lain', 'Lainnya');
          } else {
            _openSearch(categorySlug: 'hiburan-lain', categoryName: 'Lainnya');
          }
        },
      ),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return GestureDetector(
            onTap: chip.$2,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                chip.$1,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResellTypeTiles() {
    return ResellTypeTiles(
      onLimitedTap: () {
        if (widget.onResellTypeTap != null) {
          widget.onResellTypeTap!('limited');
        } else {
          _openSearch(jenis: 'limited');
        }
      },
      onLastMinuteTap: () {
        if (widget.onResellTypeTap != null) {
          widget.onResellTypeTap!('last_minute');
        } else {
          _openSearch(jenis: 'last_minute');
        }
      },
    );
  }

  /// Section utama "Acara Populer" bergaya carousel kartu foto full-bleed
  /// (dengan kartu berikutnya mengintip di kanan dan teks minimalis di bawah).
  Widget _buildPopularEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Acara Populer',
          onSeeAll: () => _openSearch(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isLoadingPopular)
          Container(
            height: 256,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (_popularError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Text(
              'Gagal memuat acara populer.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (_popularEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Belum ada acara populer saat ini.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          SizedBox(
            height: 262,
            child: PageView.builder(
              controller: _featuredPageController,
              padEnds: false,
              itemCount: _popularEvents.length,
              onPageChanged: (i) => setState(() => _activePopularPage = i),
              itemBuilder: (context, index) {
                final item = _popularEvents[index];
                final isActive = index == _activePopularPage;
                final isFirst = index == 0;
                final isLast = index == _popularEvents.length - 1;
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    left: isFirst ? AppSpacing.screenH : 6,
                    right: isLast ? AppSpacing.screenH : 6,
                    top: isActive ? 0 : 10,
                    bottom: isActive ? 0 : 10,
                  ),
                  child: _buildFeaturedEventCard(item),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedEventCard(PopularEventItem item) {
    final event = item.event;
    final resolvedPoster = EventPoster.resolveUrl(event.posterUrl);
    final dateText = _formatEventDate(event);
    final overline = [
      if (dateText.isNotEmpty) dateText else event.category.nama,
      if (item.minPrice != null) 'Mulai ${_formatPrice(item.minPrice!)}',
    ].join(' · ');

    final hasTickets = item.availableTicketsCount > 0;

    return GestureDetector(
      onTap: () => _openEventDetail(event),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedPoster != null)
              Image.network(
                resolvedPoster,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _cardImageFallback(event),
              )
            else
              _cardImageFallback(event),

            // Gradasi gelap lembut dari bawah ke atas
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Colors.black.withAlpha(20),
                    Colors.black.withAlpha(65),
                    Colors.black.withAlpha(235),
                  ],
                ),
              ),
            ),

            // Pill jumlah tiket di pojok kanan atas
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(135),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  hasTickets ? '${item.availableTicketsCount} tiket' : 'Pantau',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),

            // Teks minimalis di pojok kiri bawah (gaya referensi)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    overline,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.nama,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section "Tiket Terbaru" dengan kartu-kartu lembut seperti "Events Nearby You" di referensi.
  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Tiket Terbaru',
          onSeeAll: () => _openSearch(sort: 'terbaru'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isLoadingRecentInitial)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: LoadingState(itemCount: 3),
          )
        else if (_recentError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Text(
              'Gagal memuat tiket terbaru.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (_recentListings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Belum ada tiket yang baru ditambahkan.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            itemCount: _recentListings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _recentListings[index];
              return _buildRecentTicketCard(item);
            },
          ),
        if (_isLoadingRecentMore)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentTicketCard(ListingItem item) {
    final resolvedPoster = EventPoster.resolveUrl(item.event.posterUrl);
    return GestureDetector(
      onTap: () => _handleListingTap(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 58,
                height: 58,
                child: resolvedPoster != null
                    ? Image.network(
                        resolvedPoster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _miniFallback(),
                      )
                    : _miniFallback(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.event.nama,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.venueNama} · ${item.kota}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: CountdownBadge(eventDate: item.waktuAcara),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.jumlahTersedia} tiket',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _formatPrice(item.harga),
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniFallback() {
    return Container(
      color: AppColors.surfaceHigh,
      child: const Center(
        child: Icon(
          Icons.confirmation_number_outlined,
          color: AppColors.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _cardImageFallback(EventItem event) {
    return Container(
      color: AppColors.surfaceHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: AppColors.primary,
              size: 32,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                event.nama,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifier = widget.socketService?.unreadNotificationsNotifier;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: unreadNotifier != null
              ? ValueListenableBuilder<int>(
                  valueListenable: unreadNotifier,
                  builder: (context, unreadCount, _) => AppHeader(
                    city: _city,
                    onLocationTap: () => showLocationPickerSheet(context),
                    onNotificationTap: _openNotifications,
                    unreadNotificationsCount: unreadCount,
                  ),
                )
              : AppHeader(
                  city: _city,
                  onLocationTap: () => showLocationPickerSheet(context),
                  onNotificationTap: _openNotifications,
                ),
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceHigh,
          onRefresh: _fetchHomeData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                _buildSearchBar(),
                const SizedBox(height: AppSpacing.md),
                _buildResellTypeTiles(),
                const SizedBox(height: AppSpacing.md),
                _buildQuickFilterBar(),
                _buildUpcomingCompactCard(),
                const SizedBox(height: AppSpacing.xl),
                _buildPopularEventsSection(),
                const SizedBox(height: AppSpacing.xl),
                _buildRecentSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
