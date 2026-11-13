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
  final _customVenueController = TextEditingController();
  final _cityController = TextEditingController();
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
      final list = await _eventRepo.getVenues();
      if (mounted) setState(() => _venues = list);
    } catch (_) {}
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
      if (picked.venue != null) {
        _useCustomVenue = false;
        _selectedVenue = picked.venue;
        _cityController.text = picked.venue!.kota;
      }
      if (picked.tanggal != null &&
          picked.tanggal!.isAfter(DateTime.now())) {
        _waktuAcara = picked.tanggal;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _waktuAcara ?? now.add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? initial : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_waktuAcara ?? DateTime(2026, 1, 1, 19)),
    );
    if (!mounted) return;
    setState(() {
      _waktuAcara = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 19,
        time?.minute ?? 0,
      );
      _stepError = null;
    });
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

  bool _validateCurrentStep() {
    String? error;
    switch (_step) {
      case 0:
        if (_selectedEvent == null) {
          error = 'Pilih event terlebih dahulu.';
        } else if (!_useCustomVenue && _selectedVenue == null) {
          error = 'Pilih venue atau gunakan "Venue lainnya".';
        } else if (_useCustomVenue &&
            _customVenueController.text.trim().isEmpty) {
          error = 'Nama venue wajib diisi.';
        } else if (_cityController.text.trim().isEmpty) {
          error = 'Kota acara wajib diisi.';
        } else if (_waktuAcara == null ||
            !_waktuAcara!.isAfter(DateTime.now())) {
          error = 'Pilih tanggal & jam acara di masa depan.';
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
      'kota': _cityController.text.trim(),
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

    return SafeArea(
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
                    if (_step > 0)
                      IconButton(
                        onPressed: _submitting ? null : _prevStep,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.textPrimary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _step < 5
                            ? 'Jual Tiket (${_step + 1}/5) — ${_stepTitles[_step]}'
                            : 'Pratinjau Listing',
                        style: AppTextStyles.titleMedium,
                        overflow: TextOverflow.ellipsis,
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
                      const Icon(Icons.search_rounded, color: AppColors.primary),
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
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Venue', style: AppTextStyles.label),
            TextButton(
              onPressed: () {
                setState(() {
                  _useCustomVenue = !_useCustomVenue;
                  if (_useCustomVenue) _selectedVenue = null;
                });
              },
              child: Text(
                _useCustomVenue ? 'Pilih dari daftar' : 'Venue lainnya',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        if (_useCustomVenue)
          AppTextField(
            controller: _customVenueController,
            label: 'Nama venue manual',
            hintText: 'Contoh: Parkir Timur Senayan',
          )
        else
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _selectedVenue?.id,
            dropdownColor: AppColors.surfaceHigh,
            hint: const Text('Pilih venue'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final v in _venues)
                DropdownMenuItem<int>(
                  value: v.id,
                  child: Text(
                    '${v.nama} (${v.kota})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              final v = _venues.where((x) => x.id == id).firstOrNull;
              setState(() {
                _selectedVenue = v;
                if (v != null) _cityController.text = v.kota;
              });
            },
          ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _cityController,
          label: 'Kota acara',
          hintText: 'Contoh: Surabaya',
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Waktu acara', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: Text(
            _waktuAcara == null
                ? 'Pilih tanggal & jam acara'
                : _formatDateTime(_waktuAcara!),
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
                      '$venueName • ${_cityController.text.trim()}',
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

