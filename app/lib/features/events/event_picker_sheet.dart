import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'event_models.dart';
import 'event_repository.dart';
import 'poster_crop_dialog.dart';

/// Abstraksi pengambilan berkas gambar agar mudah di-mock saat pengujian widget.
typedef PosterBytesPicker = Future<Uint8List?> Function();

Future<Uint8List?> defaultPosterBytesPicker() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  return picked.readAsBytes();
}

/// Membuka bottom sheet pemilih event (pencarian, tambah baru, dialog "Maksudmu ini?", crop poster 2:3).
Future<EventItem?> showEventPickerSheet(
  BuildContext context, {
  required EventRepository repository,
  PosterBytesPicker? pickPosterBytes,
  String? initialCategorySlug,
}) {
  return showModalBottomSheet<EventItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => _EventPickerSheet(
      repository: repository,
      pickPosterBytes: pickPosterBytes ?? defaultPosterBytesPicker,
      initialCategorySlug: initialCategorySlug,
    ),
  );
}

class _EventPickerSheet extends StatefulWidget {
  const _EventPickerSheet({
    required this.repository,
    required this.pickPosterBytes,
    this.initialCategorySlug,
  });

  final EventRepository repository;
  final PosterBytesPicker pickPosterBytes;
  final String? initialCategorySlug;

  @override
  State<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<_EventPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _createMode = false;
  bool _loading = true;
  String? _error;

  List<EventCategory> _categories = const [];
  List<EventItem> _events = const [];
  String? _selectedCategorySlug;

  @override
  void initState() {
    super.initState();
    _selectedCategorySlug = widget.initialCategorySlug;
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _search();
      }
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.getCategories(),
        widget.repository.searchEvents(categorySlug: _selectedCategorySlug),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<EventCategory>;
        _events = results[1] as List<EventItem>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat daftar event.';
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.repository.searchEvents(
        q: _searchController.text,
        categorySlug: _selectedCategorySlug,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _createMode
              ? _CreateEventForm(
                  repository: widget.repository,
                  categories: _categories,
                  pickPosterBytes: widget.pickPosterBytes,
                  initialName: _searchController.text.trim(),
                  initialCategorySlug: _selectedCategorySlug,
                  onBack: () => setState(() => _createMode = false),
                  onCreated: (event) => Navigator.of(context).pop(event),
                  onSelectExistingId: (similarId) async {
                    final match = _events.where((e) => e.id == similarId).firstOrNull;
                    if (match != null) {
                      Navigator.of(context).pop(match);
                      return;
                    }
                    final refreshed = await widget.repository.searchEvents(
                      q: _searchController.text,
                    );
                    if (!context.mounted) return;
                    final found =
                        refreshed.where((e) => e.id == similarId).firstOrNull;
                    if (found != null) {
                      Navigator.of(context).pop(found);
                    }
                  },
                )
              : _buildSearchBody(),
        ),
      ),
    );
  }

  Widget _buildSearchBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text('Pilih event', style: AppTextStyles.titleMedium),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _createMode = true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah baru'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _searchController,
          label: 'Cari nama event',
          hintText: 'Contoh: Nada Senja, Pestapora, Dewa 19',
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: (_) {
            _searchDebounce?.cancel();
            _search();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_categories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'Semua',
                  selected: _selectedCategorySlug == null,
                  onTap: () {
                    _searchDebounce?.cancel();
                    setState(() => _selectedCategorySlug = null);
                    _search();
                  },
                ),
                for (final cat in _categories)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: _CategoryChip(
                      label: cat.nama,
                      selected: _selectedCategorySlug == cat.slug,
                      onTap: () {
                        _searchDebounce?.cancel();
                        setState(() => _selectedCategorySlug = cat.slug);
                        _search();
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.urgent),
                        ),
                      ),
                    )
                  : _events.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Event belum ditemukan.',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              PrimaryButton(
                                label: 'Tambah event baru',
                                icon: Icons.add_rounded,
                                onPressed: () =>
                                    setState(() => _createMode = true),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _events.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (ctx, i) {
                            final ev = _events[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              leading: EventPoster(
                                title: ev.nama,
                                posterUrl: ev.posterUrl,
                                categorySlug: ev.category.slug,
                                width: 42,
                                borderRadius: AppRadius.sm,
                              ),
                              title: Text(
                                ev.nama,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  ev.category.nama,
                                  if (ev.venue != null) ev.venue!.kota,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onTap: () => Navigator.of(context).pop(ev),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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

class _CreateEventForm extends StatefulWidget {
  const _CreateEventForm({
    required this.repository,
    required this.categories,
    required this.pickPosterBytes,
    required this.initialName,
    required this.onBack,
    required this.onCreated,
    required this.onSelectExistingId,
    this.initialCategorySlug,
  });

  final EventRepository repository;
  final List<EventCategory> categories;
  final PosterBytesPicker pickPosterBytes;
  final String initialName;
  final String? initialCategorySlug;
  final VoidCallback onBack;
  final ValueChanged<EventItem> onCreated;
  final Future<void> Function(int similarId) onSelectExistingId;

  @override
  State<_CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends State<_CreateEventForm> {
  late final TextEditingController _nameController;
  EventCategory? _selectedCategory;
  VenueItem? _selectedVenue;
  List<VenueItem> _venues = const [];
  final List<DateTime> _selectedDates = [];
  Uint8List? _croppedPosterBytes;
  String? _uploadedPosterUrl;
  bool _submitting = false;
  bool _uploadingPoster = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories
              .where((c) => c.slug == widget.initialCategorySlug)
              .firstOrNull ??
          widget.categories.first;
    }
    _loadVenues();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    try {
      final venues = await widget.repository.getVenues();
      if (mounted) setState(() => _venues = venues);
    } catch (_) {}
  }

  Future<void> _pickAndCropPoster() async {
    final rawBytes = await widget.pickPosterBytes();
    if (rawBytes == null || !mounted) return;

    final cropped = await showPosterCropDialog(context, rawBytes);
    if (cropped == null || !mounted) return;

    setState(() {
      _croppedPosterBytes = cropped;
      _uploadingPoster = true;
      _error = null;
    });
    try {
      final url = await widget.repository.uploadPoster(cropped);
      if (!mounted) return;
      setState(() {
        _uploadedPosterUrl = url;
        _uploadingPoster = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _uploadingPoster = false;
      });
    }
  }

  Future<void> _addDate() async {
    final now = DateTime.now();
    final firstAllowed = DateTime(now.year, now.month, now.day);
    final initial = _selectedDates.isNotEmpty
        ? _selectedDates.last.add(const Duration(days: 1))
        : firstAllowed.add(const Duration(days: 7));

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstAllowed) ? firstAllowed : initial,
      firstDate: firstAllowed,
      lastDate: firstAllowed.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      if (!_selectedDates.any((d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day)) {
        _selectedDates.add(normalized);
        _selectedDates.sort();
      }
    });
  }

  String _formatChipDate(DateTime dt) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$day, ${dt.day} $month ${dt.year}';
  }

  Future<VenueItem?> _showAddVenueDialog() async {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
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
                        final created = await widget.repository.createVenue(
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
        allowNone: !(_selectedCategory?.requiresVenue ?? false),
        onAddNewVenue: _showAddVenueDialog,
        searchRemote: (q) => widget.repository.getVenues(q: q),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedVenue = result.venue);
    }
  }

  Future<void> _submit({bool force = false}) async {
    final cat = _selectedCategory;
    if (cat == null) {
      setState(() => _error = 'Pilih kategori event terlebih dahulu.');
      return;
    }
    final nama = _nameController.text.trim();
    if (nama.length < 3) {
      setState(() => _error = 'Nama event minimal 3 karakter.');
      return;
    }
    if (cat.requiresVenue && _selectedVenue == null) {
      setState(() => _error = 'Venue wajib diisi untuk kategori ${cat.nama}.');
      return;
    }
    if (cat.requiresDate && _selectedDates.isEmpty) {
      setState(() => _error =
          'Pilih minimal satu tanggal acara untuk kategori ${cat.nama}.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final tanggalOpsi = _selectedDates
          .map((d) =>
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
          .toList();
      final created = await widget.repository.createEvent(
        categoryId: cat.id,
        nama: nama,
        posterUrl: _uploadedPosterUrl,
        venueId: _selectedVenue?.id,
        tanggal: _selectedDates.isNotEmpty ? _selectedDates.first : null,
        tanggalOpsi: tanggalOpsi.isNotEmpty ? tanggalOpsi : null,
        force: force,
      );
      if (mounted) widget.onCreated(created);
    } on SimilarEventException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showSimilarDialog(e.similar);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  Future<void> _showSimilarDialog(List<SimilarEventItem> similar) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Maksudmu ini?', style: AppTextStyles.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ada event serupa yang sudah terdaftar. Pilih salah satu atau tetap buat event baru.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in similar)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: EventPoster(
                  title: item.nama,
                  posterUrl: item.posterUrl,
                  width: 36,
                  borderRadius: AppRadius.sm,
                ),
                title: Text(item.nama, style: AppTextStyles.body),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onSelectExistingId(item.id);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submit(force: true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Tetap buat event baru'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiresVenue = _selectedCategory?.requiresVenue ?? false;
    final requiresDate = _selectedCategory?.requiresDate ?? false;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.textPrimary,
              ),
              Expanded(
                child: Text(
                  'Tambah event baru',
                  style: AppTextStyles.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.categories.isNotEmpty) ...[
            Text('Kategori', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _selectedCategory?.id,
              dropdownColor: AppColors.surfaceHigh,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nama, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                setState(() {
                  _selectedCategory =
                      widget.categories.where((c) => c.id == id).firstOrNull;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            controller: _nameController,
            label: 'Nama event',
            hintText: 'Contoh: Nada Senja Live in Surabaya',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            requiresVenue ? 'Venue (wajib)' : 'Venue (opsional)',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.md),
          Text(
            requiresDate
                ? 'Tanggal acara (wajib)'
                : 'Tanggal acara (opsional)',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_selectedDates.isEmpty)
            OutlinedButton.icon(
              onPressed: _addDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(
                requiresDate
                    ? 'Pilih tanggal acara (bisa multi tanggal)'
                    : 'Pilih tanggal acara (opsional)',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppTouchTarget.min),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final d in _selectedDates)
                  Chip(
                    label: Text(_formatChipDate(d)),
                    backgroundColor: AppColors.surfaceHigh,
                    labelStyle: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    deleteIconColor: AppColors.textSecondary,
                    onDeleted: () {
                      setState(() {
                        _selectedDates.remove(d);
                      });
                    },
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded,
                      size: 16, color: AppColors.primary),
                  label: const Text('Tambah tanggal'),
                  backgroundColor: AppColors.primary.withAlpha(20),
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  onPressed: _addDate,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              EventPoster(
                title: _nameController.text,
                posterUrl: _uploadedPosterUrl,
                previewBytes: _croppedPosterBytes,
                categorySlug: _selectedCategory?.slug,
                width: 64,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Poster event (2:3)',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _uploadedPosterUrl != null
                          ? 'Poster siap dipakai.'
                          : 'Opsional — memakai poster cadangan jika kosong.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: _uploadingPoster ? null : _pickAndCropPoster,
                      icon: const Icon(Icons.crop_rounded, size: 18),
                      label: Text(_uploadingPoster
                          ? 'Mengunggah...'
                          : 'Unggah & crop 2:3'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.urgent),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withAlpha(50)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Periksa kembali kelengkapan nama, kategori, venue, dan tanggal. Setelah dibuat, event menjadi referensi bersama dan perubahan data hanya dapat diajukan ke admin demi keamanan transaksi tiket.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Simpan Event',
            isLoading: _submitting,
            onPressed: () => _submit(),
          ),
        ],
      ),
    );
  }
}

/// Hasil dari pemilihan venue pada [VenueSearchSheet].
class VenuePickerResult {
  const VenuePickerResult(this.venue);
  final VenueItem? venue;
}

/// Bottom sheet pencarian dan pemilihan venue dengan kolom search interaktif.
class VenueSearchSheet extends StatefulWidget {
  const VenueSearchSheet({
    super.key,
    required this.venues,
    required this.selectedVenue,
    required this.allowNone,
    required this.onAddNewVenue,
    this.searchRemote,
  });

  final List<VenueItem> venues;
  final VenueItem? selectedVenue;
  final bool allowNone;
  final Future<VenueItem?> Function() onAddNewVenue;
  final Future<List<VenueItem>> Function(String q)? searchRemote;

  @override
  State<VenueSearchSheet> createState() => _VenueSearchSheetState();
}

class _VenueSearchSheetState extends State<VenueSearchSheet> {
  final _searchController = TextEditingController();
  List<VenueItem> _filteredVenues = const [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _filteredVenues = widget.venues;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    final q = val.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredVenues = widget.venues);
      return;
    }

    final local = widget.venues
        .where((v) =>
            v.nama.toLowerCase().contains(q) || v.kota.toLowerCase().contains(q))
        .toList();
    setState(() => _filteredVenues = local);

    if (widget.searchRemote != null) {
      _debounce = Timer(const Duration(milliseconds: 300), () async {
        setState(() => _loading = true);
        try {
          final remote = await widget.searchRemote!(q);
          if (!mounted) return;
          final map = {for (final v in local) v.id: v};
          for (final r in remote) {
            map[r.id] = r;
          }
          setState(() {
            _filteredVenues = map.values.toList();
            _loading = false;
          });
        } catch (_) {
          if (mounted) setState(() => _loading = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Pilih Venue', style: AppTextStyles.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final created = await widget.onAddNewVenue();
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(VenuePickerResult(created));
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah Venue'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _searchController,
                label: 'Cari venue atau kota',
                hintText: 'Contoh: Grand City, Surabaya',
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          if (widget.allowNone)
                            ListTile(
                              leading: const Icon(Icons.location_off_outlined,
                                  color: AppColors.textSecondary),
                              title: const Text('Tanpa venue khusus'),
                              trailing: widget.selectedVenue == null
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: AppColors.primary)
                                  : null,
                              onTap: () => Navigator.of(context)
                                  .pop(const VenuePickerResult(null)),
                            ),
                          if (_filteredVenues.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl),
                              child: Column(
                                children: [
                                  Text(
                                    'Venue tidak ditemukan.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  PrimaryButton(
                                    label: 'Tambah Venue Baru',
                                    icon: Icons.add_rounded,
                                    onPressed: () async {
                                      final created =
                                          await widget.onAddNewVenue();
                                      if (created != null && context.mounted) {
                                        Navigator.of(context)
                                            .pop(VenuePickerResult(created));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )
                          else
                            for (final v in _filteredVenues) ...[
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs,
                                ),
                                leading: const Icon(Icons.location_on_rounded,
                                    color: AppColors.primary),
                                title: Text(
                                  v.nama,
                                  style: AppTextStyles.body
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  [
                                    v.kota,
                                    if (v.alamat != null &&
                                        v.alamat!.isNotEmpty)
                                      v.alamat!,
                                  ].join(' • '),
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: widget.selectedVenue?.id == v.id
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.of(context)
                                    .pop(VenuePickerResult(v)),
                              ),
                              const Divider(
                                  height: 1, color: AppColors.divider),
                            ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
