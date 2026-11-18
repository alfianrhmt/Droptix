import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/primary_button.dart';
import 'moderation_repository.dart';

const List<({String code, String label})> reportReasons = [
  (code: 'penipuan', label: 'Penipuan atau transaksi mencurigakan'),
  (code: 'tiket_palsu', label: 'Tiket palsu atau tidak valid'),
  (code: 'spam', label: 'Spam atau iklan berulang'),
  (code: 'tidak_pantas', label: 'Konten atau perilaku tidak pantas'),
  (code: 'lainnya', label: 'Lainnya'),
];

Future<bool?> showReportBottomSheet(
  BuildContext context, {
  required String targetType,
  required int targetId,
  String? targetTitle,
  ModerationRepository? repository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ReportBottomSheet(
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      repository: repository,
    ),
  );
}

class ReportBottomSheet extends StatefulWidget {
  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetTitle,
    this.repository,
  });

  final String targetType;
  final int targetId;
  final String? targetTitle;
  final ModerationRepository? repository;

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  String? _selectedReason = 'penipuan';
  final TextEditingController _keteranganController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    final client = AuthScope.of(context).repository.client;
    final repo = widget.repository ?? ModerationRepository(client);

    try {
      await repo.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        alasan: _selectedReason!,
        keterangan: _keteranganController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Laporan Anda telah diterima dan akan ditinjau tim Droptix.',
          ),
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
          content: Text('Gagal mengirim laporan. Silakan coba lagi nanti.'),
          backgroundColor: AppColors.urgent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final targetLabel = widget.targetType == 'listing'
        ? 'Listing'
        : widget.targetType == 'event'
            ? 'Event'
            : 'Pengguna';

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.screenH,
        right: AppSpacing.screenH,
        top: AppSpacing.md,
        bottom: AppSpacing.lg + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Laporkan $targetLabel',
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (widget.targetTitle != null && widget.targetTitle!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.targetTitle!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Pilih alasan pelaporan:',
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...reportReasons.map((r) {
              final isSelected = _selectedReason == r.code;
              return InkWell(
                key: Key('report_reason_${r.code}'),
                onTap: () => setState(() => _selectedReason = r.code),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          r.label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('report_keterangan_field'),
              controller: _keteranganController,
              maxLength: 1000,
              maxLines: 3,
              style: AppTextStyles.bodySmall,
              decoration: InputDecoration(
                hintText: 'Keterangan tambahan (opsional)...',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                counterStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('report_submit_button'),
              label: 'Kirim Laporan',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitReport,
            ),
          ],
        ),
      ),
    );
  }
}
