import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/event_poster.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/stats_card.dart';
import '../chat/chat_repository.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_socket_service.dart';
import '../events/event_detail_screen.dart';
import '../moderation/moderation_repository.dart';
import '../moderation/report_bottom_sheet.dart';
import 'listing_models.dart';
import 'listing_repository.dart';

/// Halaman Detail Listing Tiket sesuai docs/DESIGN.md Bagian 7 dan docs/PRD.md FR-5.
/// Menampilkan seluruh informasi tiket secara transparan tanpa pernah mengekspos
/// email atau nomor WhatsApp penjual.
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.initialItem,
    this.listingRepository,
    this.chatRepository,
    this.socketService,
    this.moderationRepository,
    this.usePlaceholderChat = false,
  });

  final int listingId;
  final ListingItem? initialItem;
  final ListingRepository? listingRepository;
  final ChatRepository? chatRepository;
  final ChatSocketService? socketService;
  final ModerationRepository? moderationRepository;
  final bool usePlaceholderChat;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late final ListingRepository _repo;
  ListingItem? _item;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTogglingFavorite = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.listingRepository ??
        ListingRepository(ApiClient(tokenStorage: TokenStorage()));
    _item = widget.initialItem;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (_item == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final detail = await _repo.getListingDetail(widget.listingId);
      if (mounted) {
        setState(() {
          _item = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_item == null) {
            _errorMessage = 'Gagal memuat detail listing: ${e.toString()}';
          }
        });
      }
    }
  }

  Future<void> _handleToggleFavorite() async {
    final item = _item;
    if (item == null || _isTogglingFavorite) return;

    final auth = AuthScope.of(context);
    auth.requireAuthAction(context, () async {
      final currentFav = item.isFavorite;

      // Optimistic update
      setState(() {
        _isTogglingFavorite = true;
        _item = _cloneWithFavorite(item, !currentFav);
      });

      try {
        final serverFav = await _repo.toggleFavorite(item.id, currentFav);
        if (mounted) {
          setState(() {
            _isTogglingFavorite = false;
            _item = _cloneWithFavorite(item, serverFav);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                serverFav
                    ? 'Listing ditambahkan ke favorit'
                    : 'Listing dihapus dari favorit',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _isTogglingFavorite = false;
            _item = _cloneWithFavorite(item, currentFav);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memperbarui favorit. Silakan coba lagi.'),
            ),
          );
        }
      }
    });
  }

  ListingItem _cloneWithFavorite(ListingItem item, bool isFav) {
    return ListingItem(
      id: item.id,
      event: item.event,
      venueNama: item.venueNama,
      kota: item.kota,
      waktuAcara: item.waktuAcara,
      jenis: item.jenis,
      tipe: item.tipe,
      seksi: item.seksi,
      harga: item.harga,
      hargaAsli: item.hargaAsli,
      diskonPersen: item.diskonPersen,
      jumlahTersedia: item.jumlahTersedia,
      jumlahTerjual: item.jumlahTerjual,
      tertarik: item.tertarik,
      status: item.status,
      jarakKm: item.jarakKm,
      diperbarui: item.diperbarui,
      isFavorite: isFav,
      noKursi: item.noKursi,
      izinkanWa: item.izinkanWa,
      satuan: item.satuan,
      terikatNama: item.terikatNama,
      serahTerima: item.serahTerima,
      lokasiPenjualKota: item.lokasiPenjualKota,
      catatan: item.catatan,
      photos: item.photos,
      venue: item.venue,
      seller: item.seller,
      confirmedAt: item.confirmedAt,
      createdAt: item.createdAt,
      jumlahTotal: item.jumlahTotal,
    );
  }

  void _handleShare() {
    final item = _item;
    if (item == null) return;

    final shareText =
        'Lihat tiket ${item.event.nama} di Droptix: https://droptix.app/listings/${item.id}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan listing berhasil disalin ke papan klip!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleReportListing() {
    final item = _item;
    showReportBottomSheet(
      context,
      targetType: 'listing',
      targetId: widget.listingId,
      targetTitle: item?.event.nama ?? 'Listing #${widget.listingId}',
      repository: widget.moderationRepository,
    );
  }

  void _openChat() {
    final item = _item;
    if (item == null) return;

    final auth = AuthScope.of(context);
    auth.requireAuthAction(context, () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            listingId: item.id,
            listingDetail: item,
            chatRepository: widget.chatRepository,
            socketService: widget.socketService,
          ),
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
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d, ${dt.day} $m ${dt.year} · $hh.$mm WIB';
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'baru saja';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 30) return '${diff.inDays} hari lalu';
    return '${(diff.inDays / 30).floor()} bulan lalu';
  }

  String _formatBergabung(DateTime? dt) {
    if (dt == null) return '-';
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _formatSerahTerima(List<String> cara) {
    if (cara.isEmpty) return 'Tidak disebutkan';
    return cara.map((c) {
      switch (c) {
        case 'transfer_eticket':
          return 'Transfer E-Ticket';
        case 'cod':
          return 'COD (Ketemu langsung)';
        case 'ekspedisi':
          return 'Kirim Ekspedisi';
        default:
          return c;
      }
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: AppColors.surface,
            onSelected: (val) {
              if (val == 'report') _handleReportListing();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: AppColors.urgent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Laporkan listing', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(item),
      bottomNavigationBar: item != null ? _buildBottomChatBar(item) : null,
    );
  }

  Widget _buildBody(ListingItem? item) {
    if (_isLoading && item == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && item == null) {
      final msgLower = _errorMessage!.toLowerCase();
      final isNotFoundOrExpired = msgLower.contains('tidak ditemukan') ||
          msgLower.contains('tidak aktif') ||
          msgLower.contains('kedaluwarsa') ||
          msgLower.contains('not found') ||
          msgLower.contains('404');

      if (isNotFoundOrExpired) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: AppColors.textSecondary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Tiket Sudah Tidak Tersedia',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tiket ini telah kedaluwarsa, sudah terjual habis, atau dinonaktifkan oleh penjual.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Kembali',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.urgent, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Koneksi Terganggu',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Gagal memuat detail tiket. Periksa koneksi internet Anda.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: _fetchDetail,
              ),
            ],
          ),
        ),
      );
    }

    if (item == null) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final posterWidth = screenWidth * 0.55;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 0. Status Banner jika bukan tersedia
          if (item.status != 'tersedia') ...[
            _buildStatusAlert(item.status),
            const SizedBox(height: AppSpacing.md),
          ],

          // 2. Poster di tengah (lebar ~55% layar, radius 20)
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: EventPoster(
                title: item.event.nama,
                posterUrl: item.event.posterUrl,
                categorySlug: item.event.categorySlug,
                width: posterWidth,
                borderRadius: 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Judul event huruf kapital di tengah (titleLarge)
          Text(
            item.event.nama.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(letterSpacing: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. Baris tanggal/countdown (urgent, ikon kalender) dan baris venue (ikon pin)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 15, color: AppColors.urgent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _formatDate(item.waktuAcara),
                  style: AppTextStyles.caption.copyWith(color: AppColors.urgent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              CountdownBadge(eventDate: item.waktuAcara),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${item.venueNama}, ${item.kota}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 5. Baris aksi: Favorit dan Bagikan
          _buildActionRow(item),
          const SizedBox(height: AppSpacing.lg),

          // 6. StatsCard: Tersedia / Terjual / Tertarik
          StatsCard(
            stats: [
              StatItem(value: '${item.jumlahTersedia}', label: 'Tersedia'),
              StatItem(value: '${item.jumlahTerjual}', label: 'Terjual'),
              StatItem(value: '${item.tertarik}', label: 'Tertarik'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Pintasan ke Halaman Khusus Event
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                    eventId: item.event.id,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lihat semua tiket untuk acara ini',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 7. Detail tiket (baris label-nilai)
          _buildTicketDetailSection(item),
          const SizedBox(height: AppSpacing.xl),

          // 8. Lokasi
          _buildLocationSection(item),
          const SizedBox(height: AppSpacing.xl),

          // 9. Catatan penjual
          if (item.catatan != null && item.catatan!.trim().isNotEmpty) ...[
            _buildSellerNotesSection(item.catatan!),
            const SizedBox(height: AppSpacing.xl),
          ],

          // 10. Foto tiket dari penjual (galeri) dengan peringatan kecil QR
          _buildPhotosGallerySection(item),
          const SizedBox(height: AppSpacing.xl),

          // 11. Penjual: nama dan tanggal bergabung, diperbarui ... lalu
          _buildSellerProfileSection(item),
          const SizedBox(height: AppSpacing.xl),

          // 12. Banner disclaimer kecil: transaksi di luar tanggung jawab platform
          _buildDisclaimerBanner(),
          const SizedBox(height: 120), // Spacer agar tidak tertutup bottom bar
        ],
      ),
    );
  }

  Widget _buildStatusAlert(String status) {
    final isTerjual = status == 'terjual';
    final isKedaluwarsa = status == 'kedaluwarsa';
    final label = isTerjual
        ? 'Tiket ini telah terjual habis.'
        : (isKedaluwarsa
            ? 'Waktu acara telah lewat (listing kedaluwarsa).'
            : 'Status: $status');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isTerjual
            ? AppColors.surfaceHigh
            : AppColors.urgent.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isTerjual ? AppColors.divider : AppColors.urgent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTerjual ? Icons.check_circle_outline : Icons.info_outline_rounded,
            color: isTerjual ? AppColors.textSecondary : AppColors.urgent,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isTerjual ? AppColors.textSecondary : AppColors.urgent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListingStatusBadge(status: status),
        ],
      ),
    );
  }

  Widget _buildActionRow(ListingItem item) {
    return Row(
      children: [
        // Tombol Favorit
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('listing_favorite_button'),
            onPressed: _isTogglingFavorite ? null : _handleToggleFavorite,
            icon: Icon(
              item.isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              color: item.isFavorite ? AppColors.primary : Colors.white,
              size: 20,
            ),
            label: Text(
              item.isFavorite ? 'Tersimpan' : 'Favorit',
              style: AppTextStyles.label.copyWith(
                color: item.isFavorite ? AppColors.primary : Colors.white,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: item.isFavorite ? AppColors.primary : AppColors.divider,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Tombol Bagikan
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('listing_share_button'),
            onPressed: _handleShare,
            icon: const Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              'Bagikan',
              style: AppTextStyles.label,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.divider, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketDetailSection(ListingItem item) {
    final hasDiskon =
        item.hargaAsli != null && item.hargaAsli! > item.harga;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detail Tiket', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                'Seksi / Kategori',
                item.seksi != null && item.seksi!.isNotEmpty
                    ? (item.noKursi != null && item.noKursi!.isNotEmpty
                        ? '${item.seksi} (Kursi: ${item.noKursi})'
                        : item.seksi!)
                    : (item.noKursi != null && item.noKursi!.isNotEmpty
                        ? 'Kursi ${item.noKursi}'
                        : 'Seksi standar'),
              ),
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Tipe Tiket',
                item.tipe == 'digital' ? 'Digital (E-Ticket)' : 'Tiket Fisik',
                trailing: NeutralChip(
                  label: item.tipe == 'digital' ? 'Digital' : 'Fisik',
                ),
              ),
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Jenis Resell',
                item.jenis == 'last_minute' ? 'Last-Minute' : 'Limited',
                trailing: TypeBadge(
                  type: item.jenis == 'last_minute'
                      ? TicketType.lastMinute
                      : TicketType.limited,
                ),
              ),
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Harga per Tiket',
                _formatPrice(item.harga),
                valueStyle: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.primary),
              ),
              if (hasDiskon) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Harga Asli',
                  _formatPrice(item.hargaAsli!),
                  valueStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                  trailing: item.diskonPersen != null && item.diskonPersen! > 0
                      ? DiscountBadge(percent: item.diskonPersen!)
                      : null,
                ),
              ],
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Jumlah',
                '${item.jumlahTersedia} tiket tersedia (dari total ${item.jumlahTotal})',
              ),
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Opsi Beli',
                item.satuan ? 'Bisa dibeli satuan' : 'Ambil semua (paket)',
              ),
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Terikat Nama / KTP',
                item.terikatNama == 'ya'
                    ? 'Ya (perlu ganti nama / surat kuasa)'
                    : (item.terikatNama == 'tidak'
                        ? 'Tidak (bebas pindah tangan)'
                        : 'Tidak tahu'),
              ),
              const Divider(color: AppColors.divider, height: 20),
              _buildDetailRow(
                'Serah Terima',
                _formatSerahTerima(item.serahTerima),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    TextStyle? valueStyle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: valueStyle ?? AppTextStyles.bodySmall,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(ListingItem item) {
    final isFisik = item.tipe == 'fisik';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lokasi & Jarak', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Column(
            children: [
              if (isFisik) ...[
                _buildDetailRow(
                  'Area Penjual',
                  item.lokasiPenjualKota ?? item.kota,
                ),
              ] else ...[
                _buildDetailRow('Venue Acara', item.venueNama),
                if (item.venue?.alamat != null &&
                    item.venue!.alamat!.isNotEmpty) ...[
                  const Divider(color: AppColors.divider, height: 20),
                  _buildDetailRow('Alamat', item.venue!.alamat!),
                ],
                const Divider(color: AppColors.divider, height: 20),
                _buildDetailRow('Kota Acara', item.kota),
              ],
              if (item.jarakKm != null) ...[
                const Divider(color: AppColors.divider, height: 20),
                _buildDetailRow(
                  'Estimasi Jarak',
                  '${item.jarakKm!.toStringAsFixed(1)} km dari lokasimu',
                  valueStyle: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSellerNotesSection(String notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catatan Penjual', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Text(
            notes,
            style: AppTextStyles.body.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosGallerySection(ListingItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto Tiket dari Penjual',
            style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.security_rounded,
                  color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Peringatan: Penjual wajib menyamarkan QR/barcode tiket. Jangan bagikan kode booking sebelum tiket sah diterima.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (item.photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'Belum ada foto tiket yang diunggah penjual.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: item.photos.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, idx) {
                final photo = item.photos[idx];
                final resolvedUrl = EventPoster.resolveUrl(photo.url);
                return GestureDetector(
                  onTap: () => _showPhotoPreview(resolvedUrl ?? photo.url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 140,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: resolvedUrl != null
                          ? Image.network(
                              resolvedUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.image_not_supported_rounded,
                                    color: AppColors.textSecondary),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.image_rounded,
                                  color: AppColors.textSecondary),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showPhotoPreview(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    padding: const EdgeInsets.all(24),
                    color: AppColors.surface,
                    child: const Text('Gagal memuat gambar ukuran penuh.'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSellerProfileSection(ListingItem item) {
    final sellerName = item.seller?.nama ?? 'Penjual';
    final initial = sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'P';
    final joinedDate = _formatBergabung(item.seller?.bergabung);
    final updatedDate = _formatRelativeTime(
      item.confirmedAt ?? item.diperbarui ?? item.createdAt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Penjual', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  initial,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sellerName, style: AppTextStyles.label),
                    if (item.seller?.username != null &&
                        item.seller!.username!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${item.seller!.username}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Bergabung sejak $joinedDate',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diperbarui $updatedDate',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Perhatian: Transaksi tiket dilakukan langsung antara pembeli dan penjual. Droptix tidak menyediakan rekening bersama dan transaksi berada di luar tanggung jawab platform.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomChatBar(ListingItem item) {
    final auth = AuthScope.of(context);
    final isOwner =
        auth.user != null && auth.user!.id == item.seller?.id;
    final isUnavailable = item.status != 'tersedia';

    String buttonLabel;
    String? helperText;
    VoidCallback? onChatPressed;

    if (isOwner) {
      buttonLabel = 'Listing Milik Sendiri';
      helperText = 'Kamu adalah penjual tiket ini.';
      onChatPressed = null;
    } else if (isUnavailable) {
      buttonLabel = 'Tiket Tidak Tersedia';
      helperText = item.status == 'terjual'
          ? 'Tiket telah terjual habis.'
          : 'Acara telah lewat atau tiket tidak aktif.';
      onChatPressed = null;
    } else {
      buttonLabel = 'Chat dengan penjual';
      helperText = null;
      onChatPressed = _openChat;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        12,
        AppSpacing.screenH,
        24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            key: const Key('listing_chat_button'),
            label: buttonLabel,
            onPressed: onChatPressed,
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
