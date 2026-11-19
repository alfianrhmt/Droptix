import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../chat/chat_models.dart';
import '../chat/chat_repository.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_socket_service.dart';
import '../listings/listing_detail_screen.dart';
import '../listings/listing_models.dart';
import '../listings/listing_repository.dart';

enum ActivitySegment { selling, saved, chats }

/// Halaman Activity sesuai DESIGN.md bagian 9.
/// Tiga segmen: Selling, Saved, Chats.
/// Segmen Selling memuat daftar listing pengguna dengan aksi cepat:
/// ubah terjual, tandai terjual semua, konfirmasi masih tersedia, edit, dan hapus.
/// Segmen Saved memuat daftar listing favorit pengguna dengan status terkini.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.listingRepository,
    this.chatRepository,
    this.socketService,
    this.initialSegment = ActivitySegment.selling,
    this.onNavigateToSell,
    this.onNavigateToHome,
  });

  final ListingRepository? listingRepository;
  final ChatRepository? chatRepository;
  final ChatSocketService? socketService;
  final ActivitySegment initialSegment;
  final VoidCallback? onNavigateToSell;
  final VoidCallback? onNavigateToHome;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late ActivitySegment _segment;
  late ListingRepository _listingRepo;
  late ChatRepository _chatRepo;
  ChatSocketService? _socketService;
  bool _repoInitialized = false;

  // Status sub-filter untuk Selling: null = Semua, 'tersedia', 'terjual', 'kedaluwarsa'
  String? _statusFilter;

  List<ListingItem> _listings = [];
  bool _loading = false;
  String? _errorMessage;

  // State untuk Segmen Saved
  List<ListingItem> _savedListings = [];
  bool _savedLoading = false;
  String? _savedErrorMessage;
  int _savedPage = 1;
  bool _savedHasMore = true;
  bool _savedLoadingMore = false;
  final ScrollController _savedScrollController = ScrollController();

  // State untuk Segmen Chats
  List<ConversationModel> _conversations = [];
  bool _chatsLoading = false;
  String? _chatsErrorMessage;
  int _chatsPage = 1;
  bool _chatsHasMore = true;
  bool _chatsLoadingMore = false;
  final ScrollController _chatsScrollController = ScrollController();
  StreamSubscription? _chatsSocketSub;
  Timer? _chatsPollingTimer;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _savedScrollController.addListener(_onSavedScroll);
    _chatsScrollController.addListener(_onChatsScroll);
  }

  @override
  void dispose() {
    _savedScrollController.dispose();
    _chatsScrollController.dispose();
    _chatsSocketSub?.cancel();
    _chatsPollingTimer?.cancel();
    _socketService?.unreadCountNotifier.removeListener(_onUnreadUpdate);
    super.dispose();
  }

  void _onChatsScroll() {
    if (_chatsScrollController.position.pixels >=
            _chatsScrollController.position.maxScrollExtent - 200 &&
        !_chatsLoadingMore &&
        _chatsHasMore &&
        !_chatsLoading) {
      _chatsPage++;
      _chatsLoadingMore = true;
      _fetchConversations();
    }
  }

  void _onSavedScroll() {
    if (_savedScrollController.position.pixels >=
            _savedScrollController.position.maxScrollExtent - 200 &&
        !_savedLoadingMore &&
        _savedHasMore &&
        !_savedLoading) {
      _savedPage++;
      _savedLoadingMore = true;
      _fetchSavedListings();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final client = AuthScope.of(context).repository.client;
      _listingRepo = widget.listingRepository ?? ListingRepository(client);
      _chatRepo = widget.chatRepository ?? ChatRepository(client);
      _socketService = widget.socketService;
      _repoInitialized = true;

      _listenToSocket();

      if (_segment == ActivitySegment.selling) {
        _fetchMyListings();
      } else if (_segment == ActivitySegment.saved) {
        _fetchSavedListings();
      } else if (_segment == ActivitySegment.chats) {
        _startChatsPolling();
        _fetchConversations();
      }
    }
  }

  void _listenToSocket() {
    if (_socketService == null) return;
    _chatsSocketSub?.cancel();
    _chatsSocketSub = _socketService!.onNewMessage.listen((_) {
      if (_segment == ActivitySegment.chats && mounted) {
        _fetchConversations(isRefresh: true, isSilent: true);
      }
    });
    _socketService!.unreadCountNotifier.addListener(_onUnreadUpdate);
  }

  void _onUnreadUpdate() {
    if (_segment == ActivitySegment.chats && mounted) {
      _fetchConversations(isRefresh: true, isSilent: true);
    }
  }

  void _startChatsPolling() {
    _chatsPollingTimer?.cancel();
    _chatsPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _segment == ActivitySegment.chats) {
        _fetchConversations(isRefresh: true, isSilent: true);
      }
    });
  }

  void _stopChatsPolling() {
    _chatsPollingTimer?.cancel();
    _chatsPollingTimer = null;
  }

  Future<void> _fetchMyListings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final items = await _listingRepo.getMyListings(
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _listings = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat aktivitas. Coba lagi nanti.';
        _loading = false;
      });
    }
  }

  Future<void> _onUpdateStock(ListingItem item, int newTerjual) async {
    try {
      final updated = await _listingRepo.updateStock(item.id, newTerjual);
      if (!mounted) return;
      setState(() {
        final idx = _listings.indexWhere((x) => x.id == item.id);
        if (idx != -1) {
          _listings[idx] = updated;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok tiket berhasil diperbarui.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _onMarkAllSold(ListingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Tandai Terjual Semua?'),
        content: Text(
          'Semua ${item.jumlahTotal} tiket untuk "${item.event.nama}" akan ditandai terjual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Tandai Terjual'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _onUpdateStock(item, item.jumlahTotal);
    }
  }

  Future<void> _onConfirmListing(ListingItem item) async {
    try {
      final confirmedAt = await _listingRepo.confirmListing(item.id);
      if (!mounted) return;
      setState(() {
        final idx = _listings.indexWhere((x) => x.id == item.id);
        if (idx != -1) {
          _listings[idx] = item.copyWith(confirmedAt: confirmedAt);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ketersediaan tiket berhasil dikonfirmasi!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _onDeleteListing(ListingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus Listing Tiket?'),
        content: Text(
          'Listing "${item.event.nama}" akan dihapus. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _listingRepo.deleteListing(item.id);
        if (!mounted) return;
        setState(() {
          _listings.removeWhere((x) => x.id == item.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing berhasil dihapus.')),
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _showEditDialog(ListingItem item) async {
    final hargaController =
        TextEditingController(text: item.harga.toString());
    final hargaAsliController = TextEditingController(
      text: item.hargaAsli != null ? item.hargaAsli.toString() : '',
    );
    final catatanController =
        TextEditingController(text: item.catatan ?? '');
    var izinkanWa = item.izinkanWa;
    String? editError;

    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Listing', style: AppTextStyles.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.event.nama,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: hargaController,
                  label: 'Harga jual per tiket (Rp)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: hargaAsliController,
                  label: 'Harga asli / beli (opsional, Rp)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: catatanController,
                  label: 'Catatan tambahan (opsional)',
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: izinkanWa,
                  onChanged: (v) => setModalState(() => izinkanWa = v),
                  activeThumbColor: AppColors.primary,
                  title: Text('Izinkan lanjut via WhatsApp',
                      style: AppTextStyles.body),
                ),
                if (editError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    editError!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.urgent),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Simpan Perubahan',
                  onPressed: () async {
                    final h = int.tryParse(hargaController.text.trim());
                    if (h == null || h <= 0) {
                      setModalState(() {
                        editError = 'Harga harus lebih dari 0.';
                      });
                      return;
                    }
                    final haText = hargaAsliController.text.trim();
                    final ha = haText.isNotEmpty ? int.tryParse(haText) : null;

                    final payload = {
                      'harga': h,
                      'harga_asli': ha,
                      'catatan': catatanController.text.trim().isEmpty
                          ? null
                          : catatanController.text.trim(),
                      'izinkan_wa': izinkanWa,
                    };

                    try {
                      final updated =
                          await _listingRepo.updateListing(item.id, payload);
                      if (!mounted) return;
                      setState(() {
                        final idx =
                            _listings.indexWhere((x) => x.id == item.id);
                        if (idx != -1) {
                          _listings[idx] = updated;
                        }
                      });
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Listing berhasil diperbarui.')),
                      );
                    } on ApiException catch (e) {
                      setModalState(() {
                        editError = e.message;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangeStockDialog(ListingItem item) async {
    var curTerjual = item.jumlahTerjual;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Ubah Jumlah Terjual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sesuaikan jumlah tiket yang sudah laku terjual dari total ${item.jumlahTotal} tiket.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$curTerjual terjual',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: curTerjual > 0
                              ? () => setDialogState(() => curTerjual--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          color: AppColors.primary,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          onPressed: curTerjual < item.jumlahTotal
                              ? () => setDialogState(() => curTerjual++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          color: AppColors.primary,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sisa tiket tersedia: ${item.jumlahTotal - curTerjual}',
                style: AppTextStyles.caption.copyWith(
                  color: (item.jumlahTotal - curTerjual) == 0
                      ? AppColors.urgent
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _onUpdateStock(item, curTerjual);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Activity
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
            child: Text(
              'Activity',
              style: AppTextStyles.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Baris 3 Segmen: Selling, Saved, Chats
          _buildSegmentChips(),
          const SizedBox(height: AppSpacing.sm),
          // Konten Segmen
          Expanded(
            child: switch (_segment) {
              ActivitySegment.selling => _buildSellingContent(),
              ActivitySegment.saved => _buildSavedContent(),
              ActivitySegment.chats => _buildChatsContent(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          Expanded(
            child: _SegmentPill(
              label: 'Selling',
              isActive: _segment == ActivitySegment.selling,
              onTap: () {
                if (_segment != ActivitySegment.selling) {
                  _stopChatsPolling();
                  setState(() => _segment = ActivitySegment.selling);
                  _fetchMyListings();
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SegmentPill(
              label: 'Saved',
              isActive: _segment == ActivitySegment.saved,
              onTap: () {
                if (_segment != ActivitySegment.saved) {
                  _stopChatsPolling();
                  setState(() => _segment = ActivitySegment.saved);
                  if (_savedListings.isEmpty) {
                    _fetchSavedListings();
                  }
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SegmentPill(
              label: 'Chats',
              isActive: _segment == ActivitySegment.chats,
              onTap: () {
                if (_segment != ActivitySegment.chats) {
                  setState(() => _segment = ActivitySegment.chats);
                  _startChatsPolling();
                  _fetchConversations(isRefresh: true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-filter status
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              _StatusFilterChip(
                label: 'Semua',
                isSelected: _statusFilter == null,
                onTap: () {
                  if (_statusFilter != null) {
                    setState(() => _statusFilter = null);
                    _fetchMyListings();
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatusFilterChip(
                label: 'Tersedia',
                isSelected: _statusFilter == 'tersedia',
                onTap: () {
                  if (_statusFilter != 'tersedia') {
                    setState(() => _statusFilter = 'tersedia');
                    _fetchMyListings();
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatusFilterChip(
                label: 'Terjual',
                isSelected: _statusFilter == 'terjual',
                onTap: () {
                  if (_statusFilter != 'terjual') {
                    setState(() => _statusFilter = 'terjual');
                    _fetchMyListings();
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatusFilterChip(
                label: 'Kedaluwarsa',
                isSelected: _statusFilter == 'kedaluwarsa',
                onTap: () {
                  if (_statusFilter != 'kedaluwarsa') {
                    setState(() => _statusFilter = 'kedaluwarsa');
                    _fetchMyListings();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenH),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 48, color: AppColors.urgent),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _errorMessage!,
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ElevatedButton(
                              onPressed: _fetchMyListings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _listings.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _fetchMyListings,
                          color: AppColors.primary,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.45,
                                child: EmptyState(
                                  icon: Icons.confirmation_number_outlined,
                                  message: _statusFilter == null
                                      ? 'Belum ada tiket yang kamu jual.'
                                      : 'Tidak ada tiket dengan status "$_statusFilter".',
                                  actionLabel: 'Jual Tiket Sekarang',
                                  onAction: widget.onNavigateToSell,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchMyListings,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenH,
                              vertical: AppSpacing.sm,
                            ),
                            itemCount: _listings.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, i) {
                              final item = _listings[i];
                              return _SellingListingCard(
                                listing: item,
                                onChangeStock: () =>
                                    _showChangeStockDialog(item),
                                onMarkAllSold: () => _onMarkAllSold(item),
                                onConfirmAvailable: () =>
                                    _onConfirmListing(item),
                                onEdit: () => _showEditDialog(item),
                                onDelete: () => _onDeleteListing(item),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Future<void> _fetchSavedListings({bool isRefresh = false}) async {
    if (isRefresh) {
      _savedPage = 1;
      _savedHasMore = true;
    }
    setState(() {
      _savedLoading = _savedPage == 1 && !isRefresh;
      _savedErrorMessage = null;
    });

    try {
      final res = await _listingRepo.getMyFavorites(
        page: _savedPage,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        if (_savedPage == 1) {
          _savedListings = List.of(res.items);
        } else {
          _savedListings.addAll(res.items);
        }
        _savedHasMore = _savedListings.length < res.total;
        _savedLoading = false;
        _savedLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _savedErrorMessage = e.message;
        _savedLoading = false;
        _savedLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedErrorMessage = 'Gagal memuat tiket tersimpan. Coba lagi nanti.';
        _savedLoading = false;
        _savedLoadingMore = false;
      });
    }
  }

  Future<void> _onRemoveSavedFavorite(ListingItem item) async {
    final idx = _savedListings.indexWhere((l) => l.id == item.id);
    if (idx == -1) return;

    setState(() {
      _savedListings.removeAt(idx);
    });

    try {
      await _listingRepo.toggleFavorite(item.id, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dihapus dari favorit'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Urungkan',
            textColor: AppColors.primary,
            onPressed: () async {
              setState(() {
                _savedListings.insert(idx, item);
              });
              await _listingRepo.toggleFavorite(item.id, false);
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedListings.insert(idx, item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus favorit. Silakan coba lagi.'),
        ),
      );
    }
  }

  void _openSavedListingDetail(ListingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listingId: item.id,
          initialItem: item,
          listingRepository: _listingRepo,
        ),
      ),
    );
    _fetchSavedListings(isRefresh: true);
  }

  Widget _buildSavedContent() {
    if (_savedLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_savedErrorMessage != null && _savedListings.isEmpty) {
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
                _savedErrorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
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
          icon: Icons.star_border_rounded,
          message:
              'Tiket yang kamu simpan akan muncul di sini.\nKetuk ikon bintang pada tiket yang kamu minati di Home atau Pencarian.',
          actionLabel: widget.onNavigateToHome != null ? 'Cari Tiket' : null,
          onAction: widget.onNavigateToHome,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _fetchSavedListings(isRefresh: true),
      child: ListView.separated(
        controller: _savedScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _savedListings.length + (_savedLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
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
            onTap: () => _openSavedListingDetail(item),
            onFavoriteTap: () => _onRemoveSavedFavorite(item),
          );
        },
      ),
    );
  }

  Future<void> _fetchConversations({bool isRefresh = false, bool isSilent = false}) async {
    if (isRefresh) {
      _chatsPage = 1;
      _chatsHasMore = true;
    }
    if (!isSilent) {
      setState(() {
        _chatsLoading = _chatsPage == 1 && !isRefresh;
        _chatsErrorMessage = null;
      });
    }

    try {
      final res = await _chatRepo.getConversations(
        page: _chatsPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (isRefresh || _chatsPage == 1) {
            _conversations = res;
          } else {
            _conversations.addAll(res);
          }
          _chatsHasMore = res.length >= 20;
          _chatsLoading = false;
          _chatsLoadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (!isSilent || _conversations.isEmpty) {
          setState(() {
            _chatsErrorMessage = e.message;
            _chatsLoading = false;
            _chatsLoadingMore = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        if (!isSilent || _conversations.isEmpty) {
          setState(() {
            _chatsErrorMessage = 'Gagal memuat percakapan. Coba lagi.';
            _chatsLoading = false;
            _chatsLoadingMore = false;
          });
        }
      }
    }
  }

  Future<void> _openChat(ConversationModel conv) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          initialConversation: conv,
          chatRepository: _chatRepo,
          socketService: _socketService,
        ),
      ),
    );
    _fetchConversations(isRefresh: true);
  }

  Widget _buildChatsContent() {
    if (_chatsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_chatsErrorMessage != null && _conversations.isEmpty) {
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
                _chatsErrorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: () => _fetchConversations(isRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          message: 'Belum ada percakapan.',
          actionLabel: widget.onNavigateToHome != null ? 'Cari Tiket' : null,
          onAction: widget.onNavigateToHome,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _fetchConversations(isRefresh: true),
      child: ListView.separated(
        controller: _chatsScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _conversations.length + (_chatsLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          if (index >= _conversations.length) {
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

          final conv = _conversations[index];
          return ConversationRow(
            key: Key('chat_conversation_${conv.id}'),
            conversation: conv.toConversationData(),
            onTap: () => _openChat(conv),
          );
        },
      ),
    );
  }
}

/// Kartu listing tiket di segmen Selling dengan status badge dan aksi cepat.
class _SellingListingCard extends StatelessWidget {
  const _SellingListingCard({
    required this.listing,
    required this.onChangeStock,
    required this.onMarkAllSold,
    required this.onConfirmAvailable,
    required this.onEdit,
    required this.onDelete,
  });

  final ListingItem listing;
  final VoidCallback onChangeStock;
  final VoidCallback onMarkAllSold;
  final VoidCallback onConfirmAvailable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d, ${dt.day} $m · $hh.$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isTersedia = listing.status == 'tersedia';
    final hasAvailable = listing.jumlahTersedia > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Poster + Title + Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventPoster(
                title: listing.event.nama,
                posterUrl: listing.event.posterUrl,
                categorySlug: listing.event.categorySlug,
                width: 64,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.event.nama,
                            style: AppTextStyles.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ListingStatusBadge(status: listing.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${listing.venueNama} · ${listing.kota}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(listing.waktuAcara),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.urgent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),
          // Info Harga & Stok
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPrice(listing.harga),
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    if (listing.hargaAsli != null &&
                        listing.hargaAsli! > listing.harga)
                      Text(
                        _formatPrice(listing.hargaAsli!),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${listing.jumlahTersedia} sisa / ${listing.jumlahTotal} total',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: hasAvailable
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${listing.jumlahTerjual} terjual',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          if (listing.confirmedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Dikonfirmasi ${_formatDate(listing.confirmedAt!)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // Baris Aksi Cepat
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: [
              // Ubah jumlah terjual
              OutlinedButton.icon(
                onPressed: onChangeStock,
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Ubah Terjual'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              // Tandai terjual semua (hanya jika ada yang belum terjual)
              if (hasAvailable && isTersedia)
                OutlinedButton(
                  onPressed: onMarkAllSold,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: AppColors.urgent,
                    side: const BorderSide(color: AppColors.urgent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Terjual Semua'),
                ),
              // Konfirmasi ketersediaan (hanya jika status masih tersedia)
              if (isTersedia)
                ElevatedButton.icon(
                  onPressed: onConfirmAvailable,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Konfirmasi'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: AppColors.iconButtonFill,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.outlineTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              // Edit
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.textPrimary,
                tooltip: 'Edit listing',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              // Hapus
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.urgent,
                tooltip: 'Hapus listing',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : AppColors.chipInactive,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: isActive ? Colors.black : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.primary,
      labelStyle: AppTextStyles.caption.copyWith(
        color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}
