import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/location/location_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../events/event_models.dart';
import '../events/event_picker_sheet.dart';
import '../events/event_repository.dart';
import '../listings/listing_repository.dart';
import '../profile/edit_profile_screen.dart';

/// Alur jual tiket 5 langkah + halaman pratinjau sesuai DESIGN.md bagian 8.
class SellScreen extends StatefulWidget {
  const SellScreen({
    super.key,
    this.eventRepository,
    this.listingRepository,
    this.pickPhotoBytes,
    this.onPosted,
  });

  final EventRepository? eventRepository;
  final ListingRepository? listingRepository;
  final PosterBytesPicker? pickPhotoBytes;
  final VoidCallback? onPosted;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  // Step 0..4 = Langkah 1..5, Step 5 = Pratinjau
  int _step = 0;

  late EventRepository _eventRepo;
  late ListingRepository _listingRepo;
  bool _reposInitialized = false;

  // Langkah 1: Event, venue, waktu
  EventItem? _selectedEvent;
  List<VenueItem> _venues = const [];
  VenueItem? _selectedVenue;
  bool _useCustomVenue = false;
  bool _editingVenue = false;
  final _customVenueController = TextEditingController();
  final _cityController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _waktuAcara;

  // Langkah 2: Jenis & tipe
  String _jenis = 'limited';
  String _tipe = 'digital';
  final _seksiController = TextEditingController();
  final _kursiController = TextEditingController();

  // Langkah 3: Harga & jumlah
  final _hargaController = TextEditingController();
  final _hargaAsliController = TextEditingController();
  int _jumlahTotal = 1;
  bool _satuan = true;

  // Langkah 4: Nama & serah terima
  String _terikatNama = 'tidak';
  final Set<String> _serahTerimaFisik = {'cod'};
  final _lokasiPenjualController = TextEditingController();
  final _catatanController = TextEditingController();

  // Langkah 5: Foto & WhatsApp
  final List<_UploadedPhoto> _photos = [];
  bool _uploadingPhoto = false;
  bool _izinkanWa = false;

  bool _submitting = false;
  String? _stepError;

  static const _stepTitles = [
    'Event & Waktu',
    'Jenis & Tipe',
    'Harga & Jumlah',
    'Serah Terima',
    'Foto & Kontak',
    'Pratinjau',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reposInitialized) {
      final client = AuthScope.of(context).repository.client;
      _eventRepo = widget.eventRepository ?? EventRepository(client);
      _listingRepo = widget.listingRepository ?? ListingRepository(client);
      _reposInitialized = true;

      final auth = AuthScope.of(context);
      final location = LocationScope.maybeOf(context);
      final defaultCity = auth.user?.kota ?? location?.city ?? '';
      if (_cityController.text.isEmpty && defaultCity.isNotEmpty) {
        _cityController.text = defaultCity;
      }
      if (_lokasiPenjualController.text.isEmpty && defaultCity.isNotEmpty) {
        _lokasiPenjualController.text = defaultCity;
      }
      _loadVenues();
    }
  }

  @override
  void dispose() {
    _customVenueController.dispose();
    _cityController.dispose();
    _seksiController.dispose();
    _kursiController.dispose();
    _hargaController.dispose();
    _hargaAsliController.dispose();
    _lokasiPenjualController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    try {
      final location = LocationScope.maybeOf(context);
      final userCity = location?.city ?? AuthScope.maybeOf(context)?.user?.kota ?? 'Surabaya';
      final list = await _eventRepo.getVenues(
        userKota: userCity,
        lat: location?.lat,
        lng: location?.lng,
      );
      if (mounted) setState(() => _venues = list);
    } catch (_) {}
  }

  void _updateWaktuAcara() {
    if (_selectedDate == null) {
      _waktuAcara = null;
      return;
    }
    final time = _selectedTime ?? const TimeOfDay(hour: 19, minute: 0);
    _waktuAcara = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickEvent() async {
    final picked = await showEventPickerSheet(
      context,
      repository: _eventRepo,
      pickPosterBytes: widget.pickPhotoBytes,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedEvent = picked;
      _stepError = null;
      _editingVenue = false;

      // 1. Venue & Kota otomatis terisi dari template event jika ada
      if (picked.venue != null) {
        _useCustomVenue = false;
        _selectedVenue = picked.venue;
        _cityController.text = picked.venue!.kota;
      }

      // 2. Tanggal & Jam
      if (picked.tanggal != null) {
        _selectedDate = DateTime(
          picked.tanggal!.year,
          picked.tanggal!.month,
          picked.tanggal!.day,
        );
        _selectedTime = TimeOfDay(
          hour: picked.tanggal!.hour,
          minute: picked.tanggal!.minute,
        );
      } else if (picked.tanggalOpsi.isNotEmpty) {
        final parsed = DateTime.tryParse(picked.tanggalOpsi.first);
        if (parsed != null) {
          _selectedDate = DateTime(parsed.year, parsed.month, parsed.day);
          _selectedTime = const TimeOfDay(hour: 19, minute: 0);
        }
      }
      _updateWaktuAcara();
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final firstAllowed = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate ?? firstAllowed.add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstAllowed) ? firstAllowed : initial,
      firstDate: firstAllowed,
      lastDate: firstAllowed.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _updateWaktuAcara();
      _stepError = null;
    });
  }

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? const TimeOfDay(hour: 19, minute: 0);
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedTime = time;
      _updateWaktuAcara();
      _stepError = null;
    });
  }

  Future<VenueItem?> _showAddVenueDialog() async {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: _cityController.text.trim());
    final addressCtrl = TextEditingController();
    String? dialogError;
    bool saving = false;
    VenueItem? createdVenue;

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Tambah Venue Baru', style: AppTextStyles.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: 'Nama Venue',
                  hintText: 'Contoh: Gelora Bung Tomo',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: cityCtrl,
                  label: 'Kota',
                  hintText: 'Contoh: Surabaya',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: addressCtrl,
                  label: 'Alamat (opsional)',
                  hintText: 'Contoh: Jl. Kauman No. 1',
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    dialogError!,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.urgent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dlgCtx).pop(),
              child: const Text('Batal'),
            ),
            PrimaryButton(
              label: 'Simpan Venue',
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      final n = nameCtrl.text.trim();
                      final k = cityCtrl.text.trim();
                      final a = addressCtrl.text.trim();
                      if (n.length < 2) {
                        setDlgState(() =>
                            dialogError = 'Nama venue minimal 2 karakter.');
                        return;
                      }
                      if (k.length < 2) {
                        setDlgState(
                            () => dialogError = 'Kota minimal 2 karakter.');
                        return;
                      }
                      setDlgState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        final created = await _eventRepo.createVenue(
                          nama: n,
                          kota: k,
                          alamat: a.isEmpty ? null : a,
                        );
                        createdVenue = created;
                        if (!mounted) return;
                        setState(() {
                          if (!_venues.any((v) => v.id == created.id)) {
                            _venues = [..._venues, created];
                          }
                          _selectedVenue = created;
                          _cityController.text = created.kota;
                          _useCustomVenue = false;
                          _editingVenue = false;
                        });
                        if (dlgCtx.mounted) Navigator.of(dlgCtx).pop();
                      } on ApiException catch (e) {
                        setDlgState(() {
                          dialogError = e.message;
                          saving = false;
                        });
                      } catch (_) {
                        setDlgState(() {
                          dialogError = 'Gagal menyimpan venue.';
                          saving = false;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
    return createdVenue;
  }

  Future<void> _openVenuePicker() async {
    final location = LocationScope.maybeOf(context);
    final userCity = location?.city ?? AuthScope.maybeOf(context)?.user?.kota ?? 'Surabaya';
    final isBioskop = _selectedEvent?.category.slug == 'bioskop';
    final requiresVenue =
        (_selectedEvent?.category.requiresVenue ?? false) || isBioskop;

    final result = await showModalBottomSheet<VenuePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => VenueSearchSheet(
        venues: _venues,
        selectedVenue: _selectedVenue,
        userCity: userCity,
        allowNone: !requiresVenue,
        onAddNewVenue: _showAddVenueDialog,
        searchRemote: (q) => _eventRepo.getVenues(
          q: q,
          userKota: userCity,
          lat: location?.lat,
          lng: location?.lng,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedVenue = result.venue;
        if (result.venue != null) {
          _cityController.text = result.venue!.kota;
        }
      });
    }
  }

  String _formatIndoDate(DateTime dt) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$day, ${dt.day} $month ${dt.year}';
  }

  Future<void> _addTicketPhoto() async {
    if (_photos.length >= 3 || _uploadingPhoto) return;
    final picker = widget.pickPhotoBytes ?? defaultPosterBytesPicker;
    final bytes = await picker();
    if (bytes == null || !mounted) return;

    setState(() {
      _uploadingPhoto = true;
      _stepError = null;
    });
    try {
      final url = await _listingRepo.uploadTicketPhoto(bytes);
      if (!mounted) return;
      setState(() {
        _photos.add(_UploadedPhoto(url: url, bytes: bytes));
        _uploadingPhoto = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stepError = e.message;
        _uploadingPhoto = false;
      });
    }
  }

  String get _effectiveCity {
    if (_useCustomVenue) return _cityController.text.trim();
    return _selectedVenue?.kota ??
        _selectedEvent?.venue?.kota ??
        _cityController.text.trim();
  }

  bool _validateCurrentStep() {
    String? error;
    switch (_step) {
      case 0:
        if (_selectedEvent == null) {
          error = 'Pilih event terlebih dahulu.';
        } else {
          final cat = _selectedEvent!.category;
          final isBioskop = cat.slug == 'bioskop';
          final requiresVenueInSell = cat.requiresVenue || isBioskop;
          final requiresDateInSell = cat.requiresDate || isBioskop;
          final requiresTimeInSell = cat.requiresTime || isBioskop;

          if (requiresVenueInSell && !_useCustomVenue && _selectedVenue == null) {
            error = 'Pilih venue untuk kategori ${cat.nama}.';
          } else if (_useCustomVenue &&
              _customVenueController.text.trim().isEmpty) {
            error = 'Nama venue wajib diisi.';
          } else if (_effectiveCity.isEmpty) {
            error = 'Kota acara wajib diisi.';
          } else if (requiresDateInSell && _selectedDate == null) {
            error = isBioskop
                ? 'Pilih tanggal tayang tiket bioskop Anda.'
                : 'Pilih tanggal acara untuk tiket Anda.';
          } else if (requiresTimeInSell && _selectedTime == null) {
            error = 'Pilih jam tayang/acara untuk kategori ${cat.nama}.';
          } else if (_waktuAcara == null ||
              !_waktuAcara!.isAfter(DateTime.now())) {
            error = 'Pilih tanggal & jam acara di masa depan.';
          }
        }
        break;
      case 1:
        break;
      case 2:
        final harga = int.tryParse(_hargaController.text.trim());
        final hargaAsli = _hargaAsliController.text.trim().isEmpty
            ? null
            : int.tryParse(_hargaAsliController.text.trim());
        if (harga == null || harga <= 0) {
          error = 'Masukkan harga jual per tiket yang valid.';
        } else if (_hargaAsliController.text.trim().isNotEmpty &&
            (hargaAsli == null || hargaAsli <= 0)) {
          error = 'Harga asli harus berupa angka lebih dari 0.';
        }
        break;
      case 3:
        if (_tipe == 'fisik') {
          if (_serahTerimaFisik.isEmpty) {
            error = 'Pilih minimal satu metode serah terima (COD atau Ekspedisi).';
          } else if (_lokasiPenjualController.text.trim().isEmpty) {
            error = 'Kota penjual wajib diisi untuk tiket fisik.';
          }
        }
        break;
      case 4:
        final user = AuthScope.of(context).user;
        if (_photos.isEmpty) {
          error = 'Unggah minimal 1 foto bukti tiket.';
        } else if (user == null || (user.kota ?? '').trim().isEmpty) {
          error = 'Lengkapi kota di profil sebelum memposting tiket.';
        } else if (_izinkanWa && (user.noWa ?? '').trim().isEmpty) {
          error = 'Lengkapi nomor WhatsApp di profil untuk mengaktifkan WhatsApp.';
        }
        break;
    }

    setState(() => _stepError = error);
    return error == null;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_step < 5) {
      setState(() {
        _step++;
        _stepError = null;
      });
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _step--;
        _stepError = null;
      });
    }
  }

  Map<String, dynamic> _buildPayload() {
    final location = LocationScope.maybeOf(context);
    final harga = int.parse(_hargaController.text.trim());
    final hargaAsli = _hargaAsliController.text.trim().isEmpty
        ? null
        : int.parse(_hargaAsliController.text.trim());
    final seksi = _seksiController.text.trim();
    final kursi = _kursiController.text.trim();
    final catatan = _catatanController.text.trim();

    return {
      'event_id': _selectedEvent!.id,
      'venue_id': _useCustomVenue ? null : _selectedVenue?.id,
      'venue_teks': _useCustomVenue ? _customVenueController.text.trim() : null,
      'kota': _effectiveCity,
      'waktu_acara': _waktuAcara!.toUtc().toIso8601String(),
      'jenis': _jenis,
      'tipe': _tipe,
      'seksi': seksi.isEmpty ? null : seksi,
      'no_kursi': kursi.isEmpty ? null : kursi,
      'harga': harga,
      'harga_asli': hargaAsli,
      'jumlah_total': _jumlahTotal,
      'satuan': _satuan,
      'terikat_nama': _terikatNama,
      'serah_terima': _tipe == 'digital'
          ? ['transfer_eticket']
          : _serahTerimaFisik.toList(),
      'lokasi_penjual_kota':
          _tipe == 'fisik' ? _lokasiPenjualController.text.trim() : null,
      'lokasi_penjual_lat': _tipe == 'fisik' ? location?.lat : null,
      'lokasi_penjual_lng': _tipe == 'fisik' ? location?.lng : null,
      'catatan': catatan.isEmpty ? null : catatan,
      'izinkan_wa': _izinkanWa,
      'photos': _photos.map((p) => p.url).toList(),
    };
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _stepError = null;
    });
    try {
      await _listingRepo.createListing(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiket berhasil diposting!')),
      );
      _resetForm();
      widget.onPosted?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stepError = e.message;
        _submitting = false;
      });
    }
  }

  void _resetForm() {
    // Reset semua field termasuk city controllers (tidak di-clear saat init
    // ulang karena didChangeDependencies hanya jalan sekali).
    final auth = AuthScope.of(context);
    final location = LocationScope.maybeOf(context);
    final defaultCity = auth.user?.kota ?? location?.city ?? '';
    setState(() {
      _step = 0;
      _selectedEvent = null;
      _selectedVenue = null;
      _useCustomVenue = false;
      _editingVenue = false;
      _selectedDate = null;
      _selectedTime = null;
      _customVenueController.clear();
      _cityController.text = defaultCity;
      _waktuAcara = null;
      _jenis = 'limited';
      _tipe = 'digital';
      _seksiController.clear();
      _kursiController.clear();
      _hargaController.clear();
      _hargaAsliController.clear();
      _jumlahTotal = 1;
      _satuan = true;
      _terikatNama = 'tidak';
      _serahTerimaFisik
        ..clear()
        ..add('cod');
      _lokasiPenjualController.text = defaultCity;
      _catatanController.clear();
      _photos.clear();
      _izinkanWa = false;
      _submitting = false; // juga direset di sini agar tombol tidak freeze
      _stepError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / 6;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _prevStep();
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    if (_step > 0) {
                                      _prevStep();
                                    } else {
                                      Navigator.of(context).maybePop();
                                    }
                                  },
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.textPrimary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _step < 5
                                      ? 'Jual Tiket (${_step + 1}/5)'
                                      : 'Pratinjau Listing',
                                  style: AppTextStyles.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_step < 5) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _stepTitles[_step],
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceHigh,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.sm,
                      AppSpacing.screenH,
                      AppSpacing.lg,
                    ),
                    child: _buildStepBody(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xs,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_stepError != null) ...[
                        Text(
                          _stepError!,
                          style:
                              AppTextStyles.bodySmall.copyWith(color: AppColors.urgent),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      PrimaryButton(
                        label: _step < 5 ? 'Lanjut' : 'Posting Tiket',
                        isLoading: _submitting,
                        onPressed: _step < 5 ? _nextStep : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    return switch (_step) {
      0 => _buildStep1EventVenueTime(),
      1 => _buildStep2TypeAndSeat(),
      2 => _buildStep3PriceAndQty(),
      3 => _buildStep4Handover(),
      4 => _buildStep5PhotosAndWa(),
      _ => _buildPreview(),
    };
  }

  Widget _buildStep1EventVenueTime() {
    final cat = _selectedEvent?.category;
    final isBioskop = cat?.slug == 'bioskop';
    final requiresVenue = (cat?.requiresVenue ?? true) || isBioskop;
    final requiresDate = (cat?.requiresDate ?? true) || isBioskop;
    final requiresTime = (cat?.requiresTime ?? true) || isBioskop;

    final hasEventVenue = _selectedEvent?.venue != null;
    final hasEventDates = _selectedEvent != null &&
        (_selectedEvent!.tanggalOpsi.isNotEmpty ||
            _selectedEvent!.tanggal != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Event', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: _pickEvent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: _selectedEvent == null
                ? Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pilih atau tambah event...',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  )
                : Row(
                    children: [
                      EventPoster(
                        title: _selectedEvent!.nama,
                        posterUrl: _selectedEvent!.posterUrl,
                        categorySlug: _selectedEvent!.category.slug,
                        width: 44,
                        borderRadius: AppRadius.sm,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedEvent!.nama,
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _selectedEvent!.category.nama,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined,
                          color: AppColors.primary, size: 18),
                    ],
                  ),
          ),
        ),
        if (_selectedEvent == null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'Pilih event terlebih dahulu untuk mengisi detail tiket.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.md),

          // Section Venue
          if (hasEventVenue && !_editingVenue) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Venue',
                    style: AppTextStyles.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _editingVenue = true;
                      _selectedVenue = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Ubah venue',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedVenue?.nama ?? _selectedEvent!.venue!.nama,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_effectiveCity • Sesuai event',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    requiresVenue ? 'Venue (wajib)' : 'Venue (opsional)',
                    style: AppTextStyles.label,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _useCustomVenue = !_useCustomVenue;
                      if (_useCustomVenue) _selectedVenue = null;
                    });
                  },
                  child: Text(
                    _useCustomVenue ? 'Pilih dari daftar' : 'Venue lainnya',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_useCustomVenue) ...[
              AppTextField(
                controller: _customVenueController,
                label: 'Nama venue manual',
                hintText: 'Contoh: Parkir Timur Senayan',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _cityController,
                label: 'Kota acara',
                hintText: 'Contoh: Surabaya',
              ),
            ] else ...[
              InkWell(
                onTap: _openVenuePicker,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: _selectedVenue != null
                          ? AppColors.primary.withAlpha(80)
                          : AppColors.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: _selectedVenue != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _selectedVenue != null
                              ? '${_selectedVenue!.nama} (${_selectedVenue!.kota})'
                              : 'Cari atau pilih venue...',
                          style: AppTextStyles.body.copyWith(
                            color: _selectedVenue != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: _selectedVenue != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),

          // Section Tanggal
          Text(
            hasEventDates
                ? 'Tanggal acara'
                : (requiresDate
                    ? 'Tanggal acara (wajib)'
                    : 'Tanggal acara (opsional)'),
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_selectedEvent!.tanggalOpsi.isNotEmpty) ...[
            if (_selectedEvent!.tanggalOpsi.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Pilih tanggal tiket yang Anda miliki:',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final dStr in _selectedEvent!.tanggalOpsi)
                  Builder(
                    builder: (ctx) {
                      final parsed = DateTime.tryParse(dStr);
                      final isSelected = _selectedDate != null &&
                          parsed != null &&
                          _selectedDate!.year == parsed.year &&
                          _selectedDate!.month == parsed.month &&
                          _selectedDate!.day == parsed.day;
                      return ChoiceChip(
                        label: Text(
                          parsed != null ? _formatIndoDate(parsed) : dStr,
                        ),
                        selected: isSelected,
                        backgroundColor: AppColors.surfaceHigh,
                        selectedColor: AppColors.primary,
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color:
                              isSelected ? AppColors.primary : AppColors.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        onSelected: (selected) {
                          if (selected && parsed != null) {
                            setState(() {
                              _selectedDate =
                                  DateTime(parsed.year, parsed.month, parsed.day);
                              _updateWaktuAcara();
                              _stepError = null;
                            });
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pickCustomDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(
                _selectedDate == null
                    ? (requiresDate
                        ? 'Pilih tanggal acara (wajib)'
                        : 'Pilih tanggal acara (opsional)')
                    : _formatIndoDate(_selectedDate!),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppTouchTarget.min),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Section Jam
          Text(
            requiresTime ? 'Jam acara (wajib)' : 'Jam acara (opsional)',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time_rounded, size: 18),
            label: Text(
              _selectedTime == null
                  ? (requiresTime
                      ? 'Pilih jam acara (wajib)'
                      : 'Pilih jam acara (opsional)')
                  : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')} WIB',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppTouchTarget.min),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2TypeAndSeat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jenis resell', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        _OptionCard(
          title: 'Limited',
          subtitle: 'Tiket langka, cepat habis',
          selected: _jenis == 'limited',
          onTap: () => setState(() => _jenis = 'limited'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _OptionCard(
          title: 'Last-Minute',
          subtitle: 'Lebih murah, acara segera mulai',
          selected: _jenis == 'last_minute',
          onTap: () => setState(() => _jenis = 'last_minute'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Tipe tiket', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        _OptionCard(
          title: 'Digital (E-Ticket)',
          subtitle: 'Dikirim lewat transfer e-ticket / PDF / QR',
          selected: _tipe == 'digital',
          onTap: () => setState(() => _tipe = 'digital'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _OptionCard(
          title: 'Fisik',
          subtitle: 'Gelang atau tiket cetak (COD / ekspedisi)',
          selected: _tipe == 'fisik',
          onTap: () => setState(() => _tipe = 'fisik'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _seksiController,
          label: 'Seksi / Kategori kursi (opsional)',
          hintText: 'Contoh: CAT 2, Festival A',
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _kursiController,
          label: 'Nomor kursi (opsional)',
          hintText: 'Contoh: B12-B13',
        ),
      ],
    );
  }

  Widget _buildStep3PriceAndQty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _hargaController,
          label: 'Harga jual per tiket (Rp)',
          hintText: 'Contoh: 450000',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _hargaAsliController,
          label: 'Harga asli / beli (opsional, Rp)',
          hintText: 'Contoh: 600000 (untuk tampilkan diskon)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Jumlah tiket', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_jumlahTotal tiket', style: AppTextStyles.titleMedium),
              Row(
                children: [
                  IconButton(
                    onPressed: _jumlahTotal > 1
                        ? () => setState(() => _jumlahTotal--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _jumlahTotal++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _satuan,
          onChanged: (v) => setState(() => _satuan = v),
          activeThumbColor: AppColors.primary,
          title: Text('Bisa beli satuan', style: AppTextStyles.body),
          subtitle: Text(
            'Matikan jika pembeli wajib mengambil semua tiket sekaligus.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Handover() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Apakah tiket terikat nama?', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            _ChoicePill(
              label: 'Tidak',
              selected: _terikatNama == 'tidak',
              onTap: () => setState(() => _terikatNama = 'tidak'),
            ),
            _ChoicePill(
              label: 'Ya',
              selected: _terikatNama == 'ya',
              onTap: () => setState(() => _terikatNama = 'ya'),
            ),
            _ChoicePill(
              label: 'Tidak tahu',
              selected: _terikatNama == 'tidak_tahu',
              onTap: () => setState(() => _terikatNama = 'tidak_tahu'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Serah terima tiket', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        if (_tipe == 'digital')
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'Transfer E-Ticket (otomatis untuk tiket digital)',
              style: AppTextStyles.bodySmall,
            ),
          )
        else ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _serahTerimaFisik.contains('cod'),
            activeColor: AppColors.primary,
            title: Text('COD (ketemuan langsung)', style: AppTextStyles.body),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _serahTerimaFisik.add('cod');
                } else {
                  _serahTerimaFisik.remove('cod');
                }
              });
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _serahTerimaFisik.contains('ekspedisi'),
            activeColor: AppColors.primary,
            title: Text('Ekspedisi / kurir', style: AppTextStyles.body),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _serahTerimaFisik.add('ekspedisi');
                } else {
                  _serahTerimaFisik.remove('ekspedisi');
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _lokasiPenjualController,
            label: 'Kota lokasi penjual (untuk tiket fisik)',
            hintText: 'Contoh: Surabaya',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _catatanController,
          label: 'Catatan tambahan (opsional)',
          hintText: 'Contoh: Alasan dijual, detail lokasi COD',
        ),
      ],
    );
  }

  Widget _buildStep5PhotosAndWa() {
    final user = AuthScope.of(context).user;
    final hasNoWa = (user?.noWa ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Foto bukti tiket (1–3 foto)', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tutup bagian barcode / QR agar tidak disalahgunakan.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.memory(
                      _photos[i].bytes,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.bg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (_photos.length < 3)
              InkWell(
                onTap: _uploadingPhoto ? null : _addTicketPhoto,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.outlineTeal),
                  ),
                  child: _uploadingPhoto
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: AppColors.primary),
                            SizedBox(height: 4),
                            Text('Tambah', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _izinkanWa,
                  onChanged: (v) => setState(() => _izinkanWa = v),
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'Izinkan lanjut via WhatsApp',
                    style: AppTextStyles.label,
                  ),
                  subtitle: Text(
                    'Nomormu hanya terlihat oleh pembeli yang sudah memulai chat.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                if (_izinkanWa && !hasNoWa) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Lengkapi nomor WhatsApp di Profil'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.urgent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final venueName = _useCustomVenue
        ? _customVenueController.text.trim()
        : (_selectedVenue?.nama ?? '-');
    final harga = int.tryParse(_hargaController.text.trim()) ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EventPoster(
                title: _selectedEvent?.nama ?? '',
                posterUrl: _selectedEvent?.posterUrl,
                categorySlug: _selectedEvent?.category.slug,
                width: 64,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedEvent?.nama ?? '-',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$venueName • $_effectiveCity',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    if (_waktuAcara != null)
                      Text(
                        _formatDateTime(_waktuAcara!),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.divider),
          _PreviewRow('Jenis / Tipe',
              '${_jenis == 'last_minute' ? 'Last-Minute' : 'Limited'} • ${_tipe == 'digital' ? 'Digital' : 'Fisik'}'),
          _PreviewRow('Harga per tiket', 'Rp $harga'),
          _PreviewRow('Jumlah',
              '$_jumlahTotal tiket (${_satuan ? 'Bisa satuan' : 'Ambil semua'})'),
          _PreviewRow('Lanjut via WhatsApp',
              _izinkanWa ? 'Diizinkan' : 'Tidak aktif'),
          _PreviewRow('Foto bukti', '${_photos.length} foto siap diunggah'),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }
}

class _UploadedPhoto {
  const _UploadedPhoto({required this.url, required this.bytes});
  final String url;
  final Uint8List bytes;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.iconButtonFill : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.chipInactive,
      selectedColor: AppColors.primary,
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.onPrimary : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

