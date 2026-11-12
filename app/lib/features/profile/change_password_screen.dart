import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Layar ganti password (`PUT /me/password`).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _submitting = false;
  String? _generalError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPass = _oldCtrl.text;
    final newPass = _newCtrl.text;
    final confirmPass = _confirmCtrl.text;

    final localErrors = <String, String>{};
    if (oldPass.isEmpty) {
      localErrors['password_lama'] = 'Password lama wajib diisi.';
    }
    if (newPass.length < 8) {
      localErrors['password_baru'] = 'Password baru minimal 8 karakter.';
    }
    if (confirmPass != newPass) {
      localErrors['konfirmasi'] = 'Konfirmasi password tidak sama.';
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
      await AuthScope.of(context).changePassword(
        passwordLama: oldPass,
        passwordBaru: newPass,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diubah.')),
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
        appBar: AppBar(title: const Text('Ganti password')),
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
                  label: 'Password lama',
                  controller: _oldCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['password_lama'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Password baru',
                  controller: _newCtrl,
                  hintText: 'Minimal 8 karakter',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['password_baru'],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Konfirmasi password baru',
                  controller: _confirmCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  errorText: _fieldErrors['konfirmasi'],
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Ubah password',
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

