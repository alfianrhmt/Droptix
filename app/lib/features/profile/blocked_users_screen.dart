import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../moderation/moderation_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({
    super.key,
    this.moderationRepository,
  });

  final ModerationRepository? moderationRepository;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late ModerationRepository _repo;
  bool _repoInitialized = false;

  List<BlockedUserModel> _blockedUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      final client = AuthScope.of(context).repository.client;
      _repo = widget.moderationRepository ?? ModerationRepository(client);
      _repoInitialized = true;
      _loadBlockedUsers();
    }
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = list;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat daftar pengguna diblokir.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmUnblock(BlockedUserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Buka blokir ${user.nama}?', style: AppTextStyles.titleMedium),
        content: Text(
          'Kamu dan ${user.nama} akan dapat saling mengirim pesan kembali.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Buka Blokir',
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.unblockUser(user.id);
      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((u) => u.id == user.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blokir terhadap ${user.nama} telah dibuka.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.urgent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka blokir.'),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Pengguna Diblokir', style: AppTextStyles.titleMedium),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
              const Icon(Icons.error_outline_rounded, color: AppColors.urgent, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: _loadBlockedUsers,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_blockedUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.block_rounded,
        message: 'Belum ada pengguna yang kamu blokir.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: _blockedUsers.length,
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceHigh,
            child: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
          ),
          title: Text(
            user.nama,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          trailing: TextButton(
            key: Key('unblock_button_${user.id}'),
            onPressed: () => _confirmUnblock(user),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTextStyles.label,
            ),
            child: const Text('Buka Blokir'),
          ),
        );
      },
    );
  }
}
