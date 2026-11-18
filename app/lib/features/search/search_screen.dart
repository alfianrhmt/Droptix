import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../core/location/cities.dart';
import '../../core/location/location_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../listings/listing_models.dart';
import '../listings/listing_repository.dart';
import '../listings/listing_detail_screen.dart';
import 'recent_searches_storage.dart';

/// Halaman pencarian dan kategori tiket Droptix.
/// Mendukung filter chip (Tanggal, Urutkan, Lokasi, Jenis, Harga, Tersedia),
/// 5 pencarian terakhir, pagination scroll tanpa batas, dan empty state.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.listingRepository,
    this.recentSearchesStorage,
    this.categorySlug,
    this.categoryName,
    this.initialQuery,
    this.initialJenis,
    this.initialTanggal,
    this.initialKota,
    this.initialMaxKm,
    this.initialSort,
    this.userLat,
    this.userLng,
    this.onBack,
    this.onListingTap,
    this.onSellPressed,
  });

  final ListingRepository? listingRepository;
  final RecentSearchesStorage? recentSearchesStorage;
  final String? categorySlug;
  final String? categoryName;
  final String? initialQuery;
  final String? initialJenis;
  final String? initialTanggal;
  final String? initialKota;
  final int? initialMaxKm;
  final String? initialSort;
  final double? userLat;
  final double? userLng;
  final VoidCallback? onBack;
  final void Function(ListingItem item)? onListingTap;
  final VoidCallback? onSellPressed;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ListingRepository _repository;
  late final RecentSearchesStorage _recentStorage;

  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  String _query = '';
  String? _category;
  String? _jenis;
  String? _tanggal;
  String? _kota;
  int? _maxKm;
  int? _minHarga;
  int? _maxHarga;
  String _sort = 'relevan';
  bool _tersedia = true;

  double? _lat;
  double? _lng;

  List<String> _recentSearches = [];
  bool _showRecentSearches = false;

  final List<ListingItem> _items = [];
  int _page = 1;
  static const int _limit = 20;
  int _total = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.listingRepository ??
        ListingRepository(ApiClient(tokenStorage: TokenStorage()));
    _recentStorage = widget.recentSearchesStorage ?? RecentSearchesStorage();

    _query = widget.initialQuery ?? '';
    _category = widget.categorySlug;
    _jenis = widget.initialJenis;
    _tanggal = widget.initialTanggal;
    _kota = widget.initialKota;
    _maxKm = widget.initialMaxKm;
    _sort = widget.initialSort ?? 'relevan';
    _lat = widget.userLat;
    _lng = widget.userLng;

    _searchController = TextEditingController(text: _query);
    _focusNode = FocusNode();
    _scrollController = ScrollController();

    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);

    _loadRecentSearches();
    _fetchListings(refresh: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lat == null && _lng == null) {
      final loc = LocationScope.maybeOf(context);
      if (loc != null) {
        _lat = loc.lat;
        _lng = loc.lng;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _scrollController.removeListener(_onScroll);
    _focusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _loadRecentSearches().then((_) {
        if (mounted && _recentSearches.isNotEmpty) {
          setState(() => _showRecentSearches = true);
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoadingInitial &&
        _items.length < _total) {
      _fetchListings(refresh: false);
    }
  }

  Future<void> _loadRecentSearches() async {
    final list = await _recentStorage.getSearches();
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _fetchListings({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoadingInitial = true;
        _errorMessage = null;
        _page = 1;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final targetPage = refresh ? 1 : _page + 1;
      final result = await _repository.getListings(
        q: _query.isNotEmpty ? _query : null,
        category: _category,
        jenis: _jenis,
        kota: _kota,
        lat: _lat,
        lng: _lng,
        maxKm: _maxKm,
        minHarga: _minHarga,
        maxHarga: _maxHarga,
        tanggal: _tanggal,
        tersedia: _tersedia,
        sort: _sort,
        page: targetPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _items.clear();
          }
          _items.addAll(result.items);
          _total = result.total;
          _page = targetPage;
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _onSubmitSearch(String value) {
    final term = value.trim();
    _focusNode.unfocus();
    setState(() {
      _showRecentSearches = false;
      _query = term;
    });
    if (term.isNotEmpty) {
      _recentStorage.addSearch(term).then((_) => _loadRecentSearches());
    }
    _fetchListings(refresh: true);
  }

  void _selectRecentSearch(String term) {
    _searchController.text = term;
    _query = term;
    _focusNode.unfocus();
    setState(() {
      _showRecentSearches = false;
    });
    _recentStorage.addSearch(term).then((_) => _loadRecentSearches());
    _fetchListings(refresh: true);
  }

  Future<void> _removeRecentSearch(String term) async {
    await _recentStorage.removeSearch(term);
    await _loadRecentSearches();
    if (_recentSearches.isEmpty && mounted) {
      setState(() => _showRecentSearches = false);
    }
  }

  Future<void> _clearAllRecentSearches() async {
    await _recentStorage.clearAll();
    await _loadRecentSearches();
    if (mounted) {
      setState(() => _showRecentSearches = false);
    }
  }

  // --- Filter label helpers ---

  String get _dateFilterLabel {
    if (_tanggal == null || _tanggal == 'semua') return 'Tanggal';
    if (_tanggal == 'hari_ini') return 'Hari Ini';
    if (_tanggal == 'besok') return 'Besok';
    if (_tanggal == 'akhir_pekan') return 'Akhir Pekan';
    return _tanggal!;
  }

  String get _sortFilterLabel {
    switch (_sort) {
      case 'terdekat':
        return 'Terdekat';
      case 'termurah':
        return 'Termurah';
      case 'segera':
        return 'Paling Segera';
      case 'terbaru':
        return 'Terbaru';
      default:
        return 'Urutkan';
    }
  }

  String get _locationFilterLabel {
    if (_kota != null && _kota!.isNotEmpty) return _kota!;
    if (_maxKm != null) return '$_maxKm km';
    return 'Lokasi';
  }

  String get _jenisFilterLabel {
    if (_jenis == 'limited') return 'Limited';
    if (_jenis == 'last_minute') return 'Last-Minute';
    return 'Jenis';
  }

  String get _priceFilterLabel {
    if (_minHarga != null && _maxHarga != null) {
      return '${_formatRupiahShort(_minHarga!)} - ${_formatRupiahShort(_maxHarga!)}';
    }
    if (_minHarga != null) {
      return '> ${_formatRupiahShort(_minHarga!)}';
    }
    if (_maxHarga != null) {
      return '< ${_formatRupiahShort(_maxHarga!)}';
    }
    return 'Harga';
  }

  String _formatRupiahShort(int amount) {
    if (amount >= 1000000) {
      final jt = amount / 1000000;
      return jt % 1 == 0 ? '${jt.toInt()}jt' : '${jt.toStringAsFixed(1)}jt';
    }
    if (amount >= 1000) {
      return '${amount ~/ 1000}rb';
    }
    return '$amount';
  }

  // --- Filter Modal Bottom Sheets ---

  void _showDateFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _FilterOptionSheet(
        title: 'Filter Tanggal Acara',
        options: [
          _SheetOption(
            title: 'Semua Tanggal',
            isSelected: _tanggal == null || _tanggal == 'semua',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _tanggal = null);
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Hari Ini',
            isSelected: _tanggal == 'hari_ini',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _tanggal = 'hari_ini');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Besok',
            isSelected: _tanggal == 'besok',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _tanggal = 'besok');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Akhir Pekan Ini',
            isSelected: _tanggal == 'akhir_pekan',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _tanggal = 'akhir_pekan');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Pilih Tanggal Kalender…',
            isSelected: _tanggal != null &&
                !['hari_ini', 'besok', 'akhir_pekan', 'semua']
                    .contains(_tanggal),
            onTap: () async {
              Navigator.pop(ctx);
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                final str =
                    '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                setState(() => _tanggal = str);
                _fetchListings(refresh: true);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _FilterOptionSheet(
        title: 'Urutkan Berdasarkan',
        options: [
          _SheetOption(
            title: 'Paling Relevan',
            subtitle: 'Kombinasi waktu, popularitas, dan jarak',
            isSelected: _sort == 'relevan',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sort = 'relevan');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Terdekat dari Lokasi',
            subtitle: 'Berdasarkan koordinat GPS atau kota',
            isSelected: _sort == 'terdekat',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sort = 'terdekat');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Harga Termurah',
            subtitle: 'Tiket dengan harga paling terjangkau',
            isSelected: _sort == 'termurah',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sort = 'termurah');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Paling Segera Berakhir',
            subtitle: 'Tiket untuk acara dalam waktu dekat',
            isSelected: _sort == 'segera',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sort = 'segera');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Baru Ditambahkan',
            subtitle: 'Listing terbaru dari penjual',
            isSelected: _sort == 'terbaru',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sort = 'terbaru');
              _fetchListings(refresh: true);
            },
          ),
        ],
      ),
    );
  }

  void _showLocationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Pilih Lokasi & Jarak',
                    style: AppTextStyles.titleMedium),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _SheetOptionTile(
                      title: 'Semua Lokasi',
                      isSelected: _kota == null && _maxKm == null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _kota = null;
                          _maxKm = null;
                        });
                        _fetchListings(refresh: true);
                      },
                    ),
                    const Divider(color: AppColors.divider, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 4),
                      child: Text('Radius dari lokasi kamu',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                    for (final km in [5, 10, 20])
                      _SheetOptionTile(
                        title: 'Dalam radius $km km',
                        isSelected: _maxKm == km && _kota == null,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _maxKm = km;
                            _kota = null;
                          });
                          _fetchListings(refresh: true);
                        },
                      ),
                    const Divider(color: AppColors.divider, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 4),
                      child: Text('Kota Populer',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                    for (final city in kIndonesianCities.take(8))
                      _SheetOptionTile(
                        title: city.name,
                        isSelected: _kota?.toLowerCase() == city.name.toLowerCase(),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _kota = city.name;
                            _maxKm = null;
                          });
                          _fetchListings(refresh: true);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJenisSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _FilterOptionSheet(
        title: 'Jenis Tiket Resell',
        options: [
          _SheetOption(
            title: 'Semua Jenis',
            isSelected: _jenis == null || _jenis!.isEmpty,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _jenis = null);
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Limited (Tiket Terbatas / Langka)',
            subtitle: 'Tiket konser sold-out, festival besar, atau seat premium',
            isSelected: _jenis == 'limited',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _jenis = 'limited');
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Last-Minute (Acara Segera Mulai)',
            subtitle: 'Tiket bioskop atau event hari ini/besok dengan harga diskon',
            isSelected: _jenis == 'last_minute',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _jenis = 'last_minute');
              _fetchListings(refresh: true);
            },
          ),
        ],
      ),
    );
  }

  void _showPriceSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _FilterOptionSheet(
        title: 'Rentang Harga Tiket',
        options: [
          _SheetOption(
            title: 'Semua Harga',
            isSelected: _minHarga == null && _maxHarga == null,
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _minHarga = null;
                _maxHarga = null;
              });
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Di bawah Rp 500.000',
            isSelected: _minHarga == null && _maxHarga == 500000,
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _minHarga = null;
                _maxHarga = 500000;
              });
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Rp 500.000 - Rp 1.500.000',
            isSelected: _minHarga == 500000 && _maxHarga == 1500000,
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _minHarga = 500000;
                _maxHarga = 1500000;
              });
              _fetchListings(refresh: true);
            },
          ),
          _SheetOption(
            title: 'Di atas Rp 1.500.000',
            isSelected: _minHarga == 1500000 && _maxHarga == null,
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _minHarga = 1500000;
                _maxHarga = null;
              });
              _fetchListings(refresh: true);
            },
          ),
        ],
      ),
    );
  }

  // --- Building Widgets ---

  Widget _buildTopBar() {
    final canPop = Navigator.canPop(context) || widget.onBack != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary, size: 24),
              ),
            ),
          ],
          Expanded(
            child: AppSearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              padding: EdgeInsets.zero,
              hintText: widget.categoryName != null
                  ? 'Cari di ${widget.categoryName}…'
                  : 'Cari artis, event, tempat…',
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _query = '';
                        setState(() {});
                        _fetchListings(refresh: true);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 20),
                    )
                  : null,
              onSubmitted: _onSubmitSearch,
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBanner() {
    if (widget.categoryName == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: 4,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.primary, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.category_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  widget.categoryName!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return FilterChipRow(
      chips: [
        FilterChipData(
          label: _dateFilterLabel,
          isActive: _tanggal != null && _tanggal != 'semua',
          onTap: _showDateFilterSheet,
        ),
        FilterChipData(
          label: _sortFilterLabel,
          isActive: _sort != 'relevan',
          onTap: _showSortSheet,
        ),
        FilterChipData(
          label: _locationFilterLabel,
          isActive: (_kota != null && _kota!.isNotEmpty) || _maxKm != null,
          onTap: _showLocationSheet,
        ),
        FilterChipData(
          label: _jenisFilterLabel,
          isActive: _jenis != null && _jenis!.isNotEmpty,
          onTap: _showJenisSheet,
        ),
        FilterChipData(
          label: _priceFilterLabel,
          isActive: _minHarga != null || _maxHarga != null,
          onTap: _showPriceSheet,
        ),
        FilterChipData(
          label: 'Tersedia',
          isActive: _tersedia,
          hasDropdown: false,
          onTap: () {
            setState(() => _tersedia = !_tersedia);
            _fetchListings(refresh: true);
          },
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pencarian Terakhir',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _clearAllRecentSearches,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Hapus Semua',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.urgent),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _recentSearches.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final term = _recentSearches[index];
              return ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                leading: const Icon(Icons.history_rounded,
                    color: AppColors.textSecondary, size: 20),
                title: Text(term, style: AppTextStyles.body),
                trailing: GestureDetector(
                  onTap: () => _removeRecentSearch(term),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ),
                onTap: () => _selectRecentSearch(term),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isLoadingInitial) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: LoadingState(itemCount: 4),
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: () => _fetchListings(refresh: true),
      );
    }

    if (_items.isEmpty) {
      final msg = _query.isNotEmpty
          ? "Belum ada tiket untuk '$_query'"
          : 'Belum ada tiket yang sesuai filter.';
      return EmptyState(
        icon: Icons.search_off_rounded,
        message: msg,
        actionLabel: 'Jual tiketmu',
        onAction: widget.onSellPressed ??
            () {
              Navigator.of(context).pushNamed('/sell');
            },
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceHigh,
      onRefresh: () => _fetchListings(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 40),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
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
            );
          }
          final item = _items[index];
          return ListingRow(
            listing: item.toListingData(),
            onTap: () => _handleListingTap(item),
          );
        },
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
            listingRepository: _repository,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              _buildCategoryBanner(),
              const SizedBox(height: AppSpacing.xs),
              _buildFilterChips(),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: _showRecentSearches && _recentSearches.isNotEmpty
                    ? _buildRecentSearches()
                    : _buildResultsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Sheet Component Helpers
// ---------------------------------------------------------------------------

class _SheetOption {
  const _SheetOption({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
}

class _FilterOptionSheet extends StatelessWidget {
  const _FilterOptionSheet({
    required this.title,
    required this.options,
  });

  final String title;
  final List<_SheetOption> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(title, style: AppTextStyles.titleMedium),
              ),
              for (final opt in options)
                _SheetOptionTile(
                  title: opt.title,
                  subtitle: opt.subtitle,
                  isSelected: opt.isSelected,
                  onTap: opt.onTap,
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOptionTile extends StatelessWidget {
  const _SheetOptionTile({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
          : null,
    );
  }
}
