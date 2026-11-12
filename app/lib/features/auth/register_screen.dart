import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Layar daftar akun baru dengan kotak persetujuan syarat wajib.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _kotaCtrl = TextEditingController();

  bool _setujuSyarat = false;
  String? _generalError;
  Map<String, String> _fieldErrors = const {};
  bool _submitting = false;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _waCtrl.dispose();
    _kotaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nama = _namaCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final noWa = _waCtrl.text.trim();
    final kota = _kotaCtrl.text.trim();

    final localErrors = <String, String>{};
    if (nama.length < 2) {
      localErrors['nama'] = 'Nama minimal 2 karakter.';
    }
    if (email.isEmpty || !email.contains('@')) {
      localErrors['email'] = 'Masukkan email yang valid.';
    }
    if (password.length < 8) {
      localErrors['password'] = 'Password minimal 8 karakter.';
    }
    if (!_setujuSyarat) {
      localErrors['setuju_syarat'] =
          'Kamu wajib menyetujui Syarat Penggunaan & Kebijakan Privasi.';
    }

    if (localErrors.isNotEmpty) {
      setState(() {
        _fieldErrors = localErrors;
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
      await AuthScope.of(context).register(
        nama: nama,
        email: email,
        password: password,
        setujuSyarat: _setujuSyarat,
        noWa: noWa.isEmpty ? null : noWa,
        kota: kota.isEmpty ? null : kota,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
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
    final termsError = _fieldErrors['setuju_syarat'];

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Daftar')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buat akun Droptix',
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Isi data dirimu untuk mulai jual beli tiket.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
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
                  hintText: 'Contoh: Raka Pratama',
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['nama'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hintText: 'nama@email.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['email'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  hintText: 'Minimal 8 karakter',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['password'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'No. WhatsApp (opsional)',
                  controller: _waCtrl,
                  hintText: '081234567890',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['no_wa'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Kota (opsional)',
                  controller: _kotaCtrl,
                  hintText: 'Contoh: Surabaya',
                  textInputAction: TextInputAction.done,
                  errorText: _fieldErrors['kota'],
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () =>
                      setState(() => _setujuSyarat = !_setujuSyarat),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _setujuSyarat,
                        activeColor: AppColors.primary,
                        checkColor: AppColors.onPrimary,
                        onChanged: (v) =>
                            setState(() => _setujuSyarat = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'Saya menyetujui Syarat Penggunaan dan Kebijakan Privasi Droptix.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (termsError != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Text(
                      termsError,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.urgent),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Daftar',
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

