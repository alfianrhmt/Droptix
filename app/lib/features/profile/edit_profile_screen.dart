import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

typedef ProfilePhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> defaultProfilePhotoPicker(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}

/// Layar ubah profil pengguna (`PUT /me`), termasuk foto profil.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.pickPhotoBytes,
  });

  final ProfilePhotoPicker? pickPhotoBytes;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _kotaCtrl;

  Uint8List? _pickedPhotoBytes;
  String? _currentFotoUrl;
  bool _removePhoto = false;

  bool _initialized = false;
  bool _submitting = false;
  String? _generalError;
  Map<String, String> _fieldErrors = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = AuthScope.of(context).user;
      _namaCtrl = TextEditingController(text: user?.nama ?? '');
      _waCtrl = TextEditingController(text: user?.noWa ?? '');
      _kotaCtrl = TextEditingController(text: user?.kota ?? '');
      _currentFotoUrl = user?.fotoUrl;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _waCtrl.dispose();
    _kotaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final picker = widget.pickPhotoBytes ?? defaultProfilePhotoPicker;
      final bytes = await picker(source);
      if (bytes == null || !mounted) return;
      setState(() {
        _pickedPhotoBytes = bytes;
        _removePhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
    }
  }

  void _showPhotoOptions() {
    final hasPhoto = _pickedPhotoBytes != null ||
        (_currentFotoUrl != null && !_removePhoto);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Pilih dari Galeri',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: const Text('Ambil Foto Kamera',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              if (hasPhoto) ...[
                const Divider(color: AppColors.divider),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.urgent),
                  title: const Text('Hapus Foto Profil',
                      style: TextStyle(color: AppColors.urgent)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _pickedPhotoBytes = null;
                      _currentFotoUrl = null;
                      _removePhoto = true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final nama = _namaCtrl.text.trim();
    final noWa = _waCtrl.text.trim();
    final kota = _kotaCtrl.text.trim();

    if (nama.length < 2) {
      setState(() {
        _fieldErrors = {'nama': 'Nama minimal 2 karakter.'};
        _generalError = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _fieldErrors = const {};
      _generalError = null;
    });

    final auth = AuthScope.of(context);

    try {
      String? finalFotoUrl = _currentFotoUrl;
      if (_pickedPhotoBytes != null) {
        finalFotoUrl = await auth.uploadProfilePhoto(_pickedPhotoBytes!);
      }

      await auth.updateProfile(
        nama: nama,
        noWa: noWa,
        kota: kota,
        fotoUrl: _removePhoto ? null : finalFotoUrl,
        removeFoto: _removePhoto,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _generalError = e.fieldErrors.isEmpty ? e.message : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Terjadi kesalahan saat menyimpan profil: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit profil')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_generalError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.urgent.withAlpha(38),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _generalError!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.urgent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Foto Profil Avatar & Tombol Ubah
                Center(
                  child: Column(
                    children: [
                      UserAvatar(
                        fotoUrl: _removePhoto ? null : _currentFotoUrl,
                        nama: user?.nama,
                        radius: 46,
                        showEditBadge: true,
                        previewBytes: _pickedPhotoBytes,
                        onTap: _showPhotoOptions,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: _showPhotoOptions,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Ubah Foto Profil'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  label: 'Nama tampilan',
                  controller: _namaCtrl,
                  errorText: _fieldErrors['nama'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'No. WhatsApp',
                  controller: _waCtrl,
                  hintText: '081234567890',
                  keyboardType: TextInputType.phone,
                  errorText: _fieldErrors['no_wa'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Kota',
                  controller: _kotaCtrl,
                  hintText: 'Contoh: Surabaya',
                  errorText: _fieldErrors['kota'],
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Simpan perubahan',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
