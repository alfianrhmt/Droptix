import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Layar ubah profil pengguna (`PUT /me`).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _kotaCtrl;

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

    try {
      await AuthScope.of(context).updateProfile(
        nama: nama,
        noWa: noWa,
        kota: kota,
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
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                AppTextField(
                  label: 'Nama lengkap',
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

