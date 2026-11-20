import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../listings/listing_detail_screen.dart';
import '../listings/listing_models.dart';
import '../listings/listing_repository.dart';

/// Halaman khusus tiket yang disimpan / difavoritkan pengguna.
class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
    this.listingRepository,
    this.onNavigateToHome,
  });

  final ListingRepository? listingRepository;
  final VoidCallback? onNavigateToHome;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late ListingRepository _listingRepo;
  bool _repoInitialized = false;

  List<ListingItem> _savedListings = [];
  bool _loading = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final auth = AuthScope.of(context);
      _listingRepo = widget.listingRepository ??
          ListingRepository(auth.repository.client);
      _repoInitialized = true;
      _fetchSavedListings();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    _page++;
    await _fetchSavedListings();
  }

  Future<void> _fetchSavedListings({bool isRefresh = false}) async {
    if (isRefresh) {
      _page = 1;
      _hasMore = true;
    }
    setState(() {
      _loading = _page == 1 && !isRefresh;
      _errorMessage = null;
    });

    try {
      final res = await _listingRepo.getMyFavorites(
        page: _page,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (isRefresh || _page == 1) {
            _savedListings = List.of(res.items);
          } else {
            _savedListings.addAll(res.items);
          }
          _hasMore = _savedListings.length < res.total;
          _loading = false;
          _loadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat tiket tersimpan. Coba lagi.';
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _onUnfavorite(ListingItem item) async {
    final originalList = List<ListingItem>.from(_savedListings);
    final idx = _savedListings.indexWhere((x) => x.id == item.id);
    if (idx == -1) return;

    setState(() {
      _savedListings.removeAt(idx);
    });

    try {
      await _listingRepo.toggleFavorite(item.id, true);
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.event.nama}" dihapus dari Saved.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Batal',
            textColor: AppColors.primary,
            onPressed: () async {
              setState(() {
                _savedListings = originalList;
              });
              await _listingRepo.toggleFavorite(item.id, false);
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedListings = originalList;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui status favorit.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                child: Text('Saved', style: AppTextStyles.titleLarge),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _savedListings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _savedListings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.urgent, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: () => _fetchSavedListings(isRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_savedListings.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.bookmark_outline_rounded,
          message:
              'Simpan tiket yang kamu incar dengan mengetuk ikon simpan agar mudah dipantau kapan saja.',
          actionLabel: widget.onNavigateToHome != null ? 'Jelajahi Tiket' : null,
          onAction: widget.onNavigateToHome,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _fetchSavedListings(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _savedListings.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (ctx, index) {
          if (index >= _savedListings.length) {
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
          final item = _savedListings[index];
          return ListingRow(
            key: Key('saved_listing_${item.id}'),
            listing: item.toListingData(),
            showStatusBadge: true,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(listingId: item.id),
                ),
              );
              _fetchSavedListings(isRefresh: true);
            },
            onFavoriteTap: () => _onUnfavorite(item),
          );
        },
      ),
    );
  }
}
