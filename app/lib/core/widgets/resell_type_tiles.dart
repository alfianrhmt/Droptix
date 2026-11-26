import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Dua tombol pintasan jenis resell (Limited & Last-Minute) di bagian atas Home
/// dengan ikon vektor ilustratif duotone yang serasi dengan CategoryRow.
class ResellTypeTiles extends StatelessWidget {
  const ResellTypeTiles({
    super.key,
    this.onLimitedTap,
    this.onLastMinuteTap,
  });

  final VoidCallback? onLimitedTap;
  final VoidCallback? onLastMinuteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          Expanded(
            child: _CompactResellPill(
              title: 'Limited',
              isLimited: true,
              onTap: onLimitedTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CompactResellPill(
              title: 'Last-Minute',
              isLimited: false,
              onTap: onLastMinuteTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactResellPill extends StatelessWidget {
  const _CompactResellPill({
    required this.title,
    required this.isLimited,
    this.onTap,
  });

  final String title;
  final bool isLimited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 19,
                  height: 19,
                  child: CustomPaint(
                    painter: _ResellDuotonePainter(isLimited: isLimited),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.label.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textSecondary.withAlpha(180),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter ikon vektor duotone kustom untuk Limited (permata/tiket langka)
/// dan Last-Minute (api urgent bergaya Hot Deals referensi).
class _ResellDuotonePainter extends CustomPainter {
  const _ResellDuotonePainter({required this.isLimited});

  final bool isLimited;

  @override
  void paint(Canvas canvas, Size size) {
    if (isLimited) {
      _paintLimitedDiamond(canvas, size);
    } else {
      _paintLastMinuteFlame(canvas, size);
    }
  }

  /// Limited: Berlian / Gem langka duotone (teal cerah + facet gelap & terang).
  void _paintLimitedDiamond(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final body = Paint()..color = AppColors.primary;
    final deep = Paint()..color = const Color(0xFF0D9488);
    final light = Paint()..color = const Color(0xFFCCFBF1);

    // Siluet berlian utama
    final gem = Path()
      ..moveTo(w * 0.22, h * 0.14)
      ..lineTo(w * 0.78, h * 0.14)
      ..lineTo(w * 0.96, h * 0.40)
      ..lineTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.04, h * 0.40)
      ..close();
    canvas.drawPath(gem, body);

    // Sisi bawah kanan lebih gelap untuk dimensi
    final rightFacet = Path()
      ..moveTo(w * 0.50, h * 0.40)
      ..lineTo(w * 0.96, h * 0.40)
      ..lineTo(w * 0.50, h * 0.90)
      ..close();
    canvas.drawPath(rightFacet, deep);

    // Mahkota atas tengah lebih terang
    final topCenter = Path()
      ..moveTo(w * 0.34, h * 0.14)
      ..lineTo(w * 0.66, h * 0.14)
      ..lineTo(w * 0.50, h * 0.40)
      ..close();
    canvas.drawPath(topCenter, light);
  }

  /// Last-Minute: Api duotone (oranye-coral + inti terang) bergaya referensi.
  void _paintLastMinuteFlame(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final outer = Paint()..color = const Color(0xFFFB7185);
    final mid = Paint()..color = const Color(0xFFFB923C);
    final inner = Paint()..color = const Color(0xFFFDE68A);

    // Lidah api luar
    final flameOuter = Path()
      ..moveTo(w * 0.52, h * 0.06)
      ..cubicTo(w * 0.76, h * 0.28, w * 0.90, h * 0.48, w * 0.84, h * 0.70)
      ..cubicTo(w * 0.78, h * 0.88, w * 0.64, h * 0.94, w * 0.50, h * 0.94)
      ..cubicTo(w * 0.30, h * 0.94, w * 0.14, h * 0.80, w * 0.16, h * 0.58)
      ..cubicTo(w * 0.17, h * 0.44, w * 0.26, h * 0.34, w * 0.32, h * 0.28)
      ..cubicTo(w * 0.30, h * 0.40, w * 0.36, h * 0.44, w * 0.40, h * 0.40)
      ..cubicTo(w * 0.44, h * 0.30, w * 0.44, h * 0.16, w * 0.52, h * 0.06)
      ..close();
    canvas.drawPath(flameOuter, outer);

    // Lapisan api tengah (oranye)
    final flameMid = Path()
      ..moveTo(w * 0.52, h * 0.32)
      ..cubicTo(w * 0.68, h * 0.48, w * 0.76, h * 0.62, w * 0.70, h * 0.78)
      ..cubicTo(w * 0.65, h * 0.89, w * 0.57, h * 0.93, w * 0.49, h * 0.93)
      ..cubicTo(w * 0.36, h * 0.93, w * 0.27, h * 0.82, w * 0.29, h * 0.68)
      ..cubicTo(w * 0.31, h * 0.54, w * 0.44, h * 0.44, w * 0.52, h * 0.32)
      ..close();
    canvas.drawPath(flameMid, mid);

    // Inti api terang
    final flameInner = Path()
      ..moveTo(w * 0.50, h * 0.56)
      ..cubicTo(w * 0.60, h * 0.66, w * 0.62, h * 0.78, w * 0.56, h * 0.87)
      ..cubicTo(w * 0.53, h * 0.91, w * 0.47, h * 0.91, w * 0.43, h * 0.87)
      ..cubicTo(w * 0.38, h * 0.80, w * 0.40, h * 0.66, w * 0.50, h * 0.56)
      ..close();
    canvas.drawPath(flameInner, inner);
  }

  @override
  bool shouldRepaint(covariant _ResellDuotonePainter oldDelegate) =>
      oldDelegate.isLimited != isLimited;
}
