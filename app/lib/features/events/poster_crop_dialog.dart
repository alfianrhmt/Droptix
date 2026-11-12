import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Dialog interaktif untuk memotong (crop) poster event ke rasio 2:3.
Future<Uint8List?> showPosterCropDialog(
  BuildContext context,
  Uint8List imageBytes,
) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PosterCropDialog(imageBytes: imageBytes),
  );
}

class _PosterCropDialog extends StatefulWidget {
  const _PosterCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_PosterCropDialog> createState() => _PosterCropDialogState();
}

class _PosterCropDialogState extends State<_PosterCropDialog> {
  final _boundaryKey = GlobalKey();
  bool _exporting = false;

  Future<void> _confirmCrop() async {
    setState(() => _exporting = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(widget.imageBytes);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (mounted) {
        Navigator.of(context).pop(bytes ?? widget.imageBytes);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop(widget.imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sesuaikan poster (2:3)', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Geser atau cubit gambar agar pas dalam bingkai.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Container(
                        color: AppColors.bg,
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _exporting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppTouchTarget.min),
                      side: const BorderSide(color: AppColors.divider),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: 'Pakai Poster',
                    isLoading: _exporting,
                    onPressed: _confirmCrop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

