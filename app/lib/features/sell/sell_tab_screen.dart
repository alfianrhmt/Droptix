import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../events/event_picker_sheet.dart';
import '../events/event_repository.dart';
import '../listings/listing_models.dart';
import '../listings/listing_repository.dart';
import 'sell_screen.dart';

/// Halaman utama tab Sell (Opsi A):
/// Menampilkan daftar penjualan tiket pengguna ("Tiket Saya"), kontrol stok,
/// edit/hapus, serta tombol mencolok "+ Jual Tiket" untuk membuka alur posting.
class SellTabScreen extends StatefulWidget {
  const SellTabScreen({
    super.key,
    this.listingRepository,
    this.eventRepository,
    this.pickPhotoBytes,
  });

  final ListingRepository? listingRepository;
  final EventRepository? eventRepository;
  final PosterBytesPicker? pickPhotoBytes;

  @override
  State<SellTabScreen> createState() => _SellTabScreenState();
}

class _SellTabScreenState extends State<SellTabScreen> {
  late ListingRepository _listingRepo;
  bool _repoInitialized = false;

  String? _statusFilter;
  List<ListingItem> _listings = [];
  bool _loading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final auth = AuthScope.of(context);
      _listingRepo = widget.listingRepository ??
          ListingRepository(auth.repository.client);
      _repoInitialized = true;
      _fetchMyListings();
    }
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
        _errorMessage = 'Gagal memuat daftar penjualan. Coba lagi nanti.';
        _loading = false;
      });
    }
  }

  Future<void> _openSellWizard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SellScreen(
          eventRepository: widget.eventRepository,
          listingRepository: _listingRepo,
          pickPhotoBytes: widget.pickPhotoBytes,
          onPosted: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) {
      _fetchMyListings();
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

  Future<void> _showChangeStockDialog(ListingItem item) async {
    int currentSold = item.jumlahTerjual;
    final total = item.jumlahTotal;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Ubah Jumlah Terjual', style: AppTextStyles.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.event.nama,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: currentSold > 0
                        ? () => setDialogState(() => currentSold--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    iconSize: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '$currentSold',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  IconButton(
                    onPressed: currentSold < total
                        ? () => setDialogState(() => currentSold++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    iconSize: 32,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tersedia: ${total - currentSold} / Total: $total',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (currentSold != item.jumlahTerjual) {
                  _onUpdateStock(item, currentSold);
                }
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
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
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
        const SnackBar(
            content: Text('Ketersediaan tiket berhasil dikonfirmasi!')),
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
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
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
    final catatanController = TextEditingController(text: item.catatan ?? '');
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
                  title:
                      Text('Izinkan lanjut via WhatsApp', style: AppTextStyles.body),
                ),
                if (editError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    editError!,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.urgent),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header: Judul & Tombol + Jual Tiket
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Penjualan', style: AppTextStyles.titleLarge),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _openSellWizard,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Jual Tiket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ],
            ),
          ),

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

          // Konten Daftar Tiket Penjualan
          Expanded(child: _buildContent()),
        ],
      ),
    ),
  );
}

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
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
      );
    }

    if (_listings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMyListings,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: EmptyState(
                icon: Icons.sell_outlined,
                message: _statusFilter == null
                    ? 'Punya tiket lebih? Jual tiketmu sekarang dan temukan pembeli dengan mudah.'
                    : 'Tidak ada tiket dengan status "$_statusFilter".',
                actionLabel: 'Jual Tiket Sekarang',
                onAction: _openSellWizard,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyListings,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.sm,
        ),
        itemCount: _listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final item = _listings[i];
          return _SellingCard(
            listing: item,
            onChangeStock: () => _showChangeStockDialog(item),
            onMarkAllSold: () => _onMarkAllSold(item),
            onConfirmAvailable: () => _onConfirmListing(item),
            onEdit: () => _showEditDialog(item),
            onDelete: () => _onDeleteListing(item),
          );
        },
      ),
    );
  }
}

class _SellingCard extends StatelessWidget {
  const _SellingCard({
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
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: [
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
              if (isTersedia)
                ElevatedButton.icon(
                  onPressed: onConfirmAvailable,
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 16),
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
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.textPrimary,
                tooltip: 'Edit listing',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
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
