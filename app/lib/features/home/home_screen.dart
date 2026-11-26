import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../core/location/location_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../events/event_models.dart';
import '../events/event_repository.dart';
import '../events/event_detail_screen.dart';
import '../listings/listing_models.dart';
import '../listings/listing_repository.dart';
import '../listings/listing_detail_screen.dart';
import '../location/location_picker_sheet.dart';
import '../search/search_screen.dart';

/// Halaman Home Droptix sesuai docs/DESIGN.md bagian 5 dan docs/PRD.md FR-3.
/// Urutan:
/// 1. AppHeader (wordmark Droptix + pil lokasi)
/// 2. SearchBar (tappable -> membuka SearchScreen)
/// 3. BannerCarousel (event ramai / terdekat dari GET /events/trending)
/// 4. ResellTypeTiles (Limited, Last-Minute)
/// 5. CategoryRow (Konser & Festival, Bioskop, Olahraga, Wisata, Lainnya)
/// 6. Carousel "Dekat Kamu" (PosterCard horizontal)
/// 7. Section "Segera Berakhir" (ListingRow vertikal)
/// 8. Section "Baru Ditambahkan" (ListingRow vertikal, scroll tanpa batas)
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.listingRepository,
    this.eventRepository,
    this.onNavigateToTab,
    this.onListingTap,
    this.onSearchTap,
    this.onCategoryTap,
    this.onDateFilterTap,
    this.onResellTypeTap,
  });

  final ListingRepository? listingRepository;
  final EventRepository? eventRepository;
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

  String _city = 'Surabaya';
  double? _lat;
  double? _lng;

  // 1. Trending / Promotional Banners
  List<BannerItem> _banners = [];
  bool _isLoadingBanners = true;
  String? _bannersError;

  // 1b. Acara Populer
  List<PopularEventItem> _popularEvents = [];
  bool _isLoadingPopular = true;
  String? _popularError;

  // 2. Segera Berakhir
  List<ListingItem> _endingSoonListings = [];
  bool _isLoadingEndingSoon = true;
  String? _endingSoonError;

  // 4. Baru Ditambahkan (Pagination)
  final List<ListingItem> _recentListings = [];
  int _recentPage = 1;
  static const int _recentLimit = 20;
  int _recentTotal = 0;
  bool _isLoadingRecentInitial = true;
  bool _isLoadingRecentMore = false;
  String? _recentError;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(tokenStorage: TokenStorage());
    _listingRepo = widget.listingRepository ?? ListingRepository(apiClient);
    _eventRepo = widget.eventRepository ?? EventRepository(apiClient);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  bool _isFirstDependencyCheck = true;

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
      _loadTrendingBanners(),
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

  Future<void> _loadTrendingBanners() async {
    setState(() {
      _isLoadingBanners = true;
      _bannersError = null;
    });
    try {
      // 1. Coba ambil banner editorial / promosi dari GET /banners
      List<AppBanner> appBanners = [];
      try {
        appBanners = await _eventRepo.getBanners();
      } catch (_) {
        appBanners = [];
      }

      if (appBanners.isNotEmpty) {
        if (mounted) {
          setState(() {
            _banners = appBanners.map((b) => b.toBannerItem()).toList();
            _isLoadingBanners = false;
          });
        }
        return;
      }

      // 2. Fallback ke trending banners jika banners kosong
      final trending = await _eventRepo.getTrending(lat: _lat, lng: _lng);
      if (mounted) {
        setState(() {
          _banners = trending.map((b) => b.toBannerItem()).toList();
          _isLoadingBanners = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bannersError = e.toString();
          _isLoadingBanners = false;
        });
      }
    }
  }

  Future<void> _loadEndingSoonListings() async {
    setState(() {
      _isLoadingEndingSoon = true;
      _endingSoonError = null;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _endingSoonError = e.toString();
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

  // --- Navigasi ke SearchScreen ---

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

  // --- Sub-widgets Builder ---

  Widget _buildBanners() {
    if (_isLoadingBanners) {
      return Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_bannersError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Center(
            child: Text(
              'Gagal memuat banner trending.',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return BannerCarousel(
      items: _banners,
      onTap: (item) {
        final banner = item.appBanner;
        if (banner is AppBanner) {
          switch (banner.targetType) {
            case 'event':
              final eventId = int.tryParse(banner.targetPayload ?? '');
              if (eventId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventDetailScreen(eventId: eventId),
                  ),
                );
                return;
              }
              break;
            case 'category':
              final catSlug = banner.targetPayload ?? '';
              if (widget.onCategoryTap != null) {
                widget.onCategoryTap!(catSlug, banner.title);
              } else {
                _openSearch(categorySlug: catSlug);
              }
              return;
            case 'sell':
              widget.onNavigateToTab?.call(2);
              return;
            case 'filter':
              final payload = banner.targetPayload ?? 'last_minute';
              if (widget.onResellTypeTap != null) {
                widget.onResellTypeTap!(payload);
              } else {
                _openSearch(jenis: payload);
              }
              return;
            case 'search':
            default:
              if (banner.targetPayload == 'trending') {
                _openSearch(sort: 'tren');
              } else {
                final q = banner.targetPayload ?? banner.title;
                if (widget.onSearchTap != null) {
                  widget.onSearchTap!(q);
                } else {
                  _openSearch(query: q);
                }
              }
              return;
          }
        }

        if (widget.onSearchTap != null) {
          widget.onSearchTap!(item.keyword ?? item.eventName);
        } else {
          _openSearch(query: item.keyword ?? item.eventName);
        }
      },
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

  Widget _buildCategoryRow() {
    const categoriesWithSlugs = [
      ('Konser', 'konser-festival', Icons.music_note_rounded),
      ('Bioskop', 'bioskop', Icons.movie_rounded),
      ('Olahraga', 'olahraga', Icons.sports_soccer_rounded),
      ('Lainnya', 'hiburan-lain', Icons.more_horiz_rounded),
    ];

    final items = categoriesWithSlugs
        .map((cat) => CategoryItem(
              label: cat.$1,
              icon: cat.$3,
              onTap: () {
                if (widget.onCategoryTap != null) {
                  widget.onCategoryTap!(cat.$2, cat.$1);
                } else {
                  _openSearch(categorySlug: cat.$2, categoryName: cat.$1);
                }
              },
            ))
        .toList();

    return CategoryRow(categories: items);
  }

  Widget _buildPopularEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Acara Populer',
          onSeeAll: () => _openSearch(),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isLoadingPopular)
          Container(
            height: 240,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
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
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (_popularEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
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
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              itemCount: _popularEvents.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = _popularEvents[index];
                final event = item.event;
                final subtitle = event.venue != null
                    ? '${event.venue!.nama}, ${event.venue!.kota}'
                    : (event.category.slug == 'bioskop'
                        ? 'Bioskop · Multi-Lokasi'
                        : event.category.nama);
                return EventPosterCard(
                  eventName: event.nama,
                  subtitle: subtitle,
                  ticketCount: item.availableTicketsCount,
                  minPrice: item.minPrice,
                  posterUrl: event.posterUrl,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventDetailScreen(
                          eventId: event.id,
                          initialEvent: event,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEndingSoonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Segera Berakhir',
          onSeeAll: () => _openSearch(sort: 'segera'),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isLoadingEndingSoon)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: LoadingState(itemCount: 2),
          )
        else if (_endingSoonError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Text(
              'Gagal memuat tiket segera berakhir.',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (_endingSoonListings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Tidak ada acara yang segera berakhir dalam 24 jam.',
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
            padding: EdgeInsets.zero,
            itemCount: _endingSoonListings.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final item = _endingSoonListings[index];
              return ListingRow(
                listing: item.toListingData(),
                onTap: () => _handleListingTap(item),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Baru Ditambahkan',
          showSeeAll: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isLoadingRecentInitial)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: LoadingState(itemCount: 3),
          )
        else if (_recentError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Text(
              'Gagal memuat tiket baru ditambahkan.',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (_recentListings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
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
            padding: EdgeInsets.zero,
            itemCount: _recentListings.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final item = _recentListings[index];
              return ListingRow(
                listing: item.toListingData(),
                onTap: () => _handleListingTap(item),
              );
            },
          ),
        if (_isLoadingRecentMore)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
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

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppHeader(
          city: _city,
          onLocationTap: () => showLocationPickerSheet(context),
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceHigh,
          onRefresh: _fetchHomeData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                AppSearchBar(
                  readOnly: true,
                  onTap: () => _openSearch(),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildBanners(),
                const SizedBox(height: AppSpacing.xl),
                _buildResellTypeTiles(),
                const SizedBox(height: AppSpacing.xl),
                _buildCategoryRow(),
                const SizedBox(height: AppSpacing.xxl),
                _buildPopularEventsSection(),
                const SizedBox(height: AppSpacing.xxl),
                _buildEndingSoonSection(),
                const SizedBox(height: AppSpacing.xxl),
                _buildRecentSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
