import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import 'blocked_users_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

/// Halaman Profile (DESIGN.md bagian 9b).
/// Menampilkan ajakan masuk untuk tamu, atau menu profil untuk pengguna login.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, AuthController auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Keluar dari akun?', style: AppTextStyles.titleMedium),
        content: Text(
          'Kamu perlu masuk lagi untuk jual tiket atau chat.',
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Keluar',
              style: AppTextStyles.label.copyWith(color: AppColors.urgent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.logout();
    }
  }

  void _showPlaceholder(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title akan tersedia pada milestone berikutnya.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;

    if (user == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Profile', style: AppTextStyles.titleLarge),
              const Spacer(),
              const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
                size: 56,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Masuk ke Droptix',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Kamu bisa mencari tiket tanpa akun. Masuk atau daftar untuk menjual tiket, menyimpan favorit, dan chat.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Masuk',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Daftar akun baru',
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.lg,
        ),
        children: [
          Text('Profile', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.nama, style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (user.kota != null && user.kota!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kota: ${user.kota}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                if (user.noWa != null && user.noWa!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'WhatsApp: +${user.noWa}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _MenuRow(
            icon: Icons.edit_outlined,
            label: 'Edit profil',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          _MenuRow(
            icon: Icons.lock_outline_rounded,
            label: 'Ganti password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          _MenuRow(
            icon: Icons.block_rounded,
            label: 'Pengguna diblokir',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            ),
          ),
          _MenuRow(
            icon: Icons.description_outlined,
            label: 'Syarat Penggunaan',
            onTap: () => _showPlaceholder(context, 'Syarat Penggunaan'),
          ),
          _MenuRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Kebijakan Privasi',
            onTap: () => _showPlaceholder(context, 'Kebijakan Privasi'),
          ),
          const Divider(color: AppColors.divider, height: AppSpacing.xl),
          _MenuRow(
            icon: Icons.logout_rounded,
            label: 'Keluar',
            color: AppColors.urgent,
            showArrow: false,
            onTap: () => _confirmLogout(context, auth),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.showArrow = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: color),
                ),
              ),
              if (showArrow)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

