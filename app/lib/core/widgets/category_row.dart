import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Jenis ilustrasi duotone kustom untuk tiap kategori.
enum CategoryIconType {
  concert,
  cinema,
  sports,
  voucher,
  other,
}

/// Data model kategori.
class CategoryItem {
  const CategoryItem({
    required this.label,
    required this.icon,
    this.iconType,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final CategoryIconType? iconType;
  final VoidCallback? onTap;
}

/// 5 Kategori bawaan: Konser, Bioskop, Olahraga, Voucher, Lainnya.
const List<CategoryItem> defaultCategories = [
  CategoryItem(
    label: 'Konser',
    icon: Icons.music_note_rounded,
    iconType: CategoryIconType.concert,
  ),
  CategoryItem(
    label: 'Bioskop',
    icon: Icons.movie_rounded,
    iconType: CategoryIconType.cinema,
  ),
  CategoryItem(
    label: 'Olahraga',
    icon: Icons.sports_soccer_rounded,
    iconType: CategoryIconType.sports,
  ),
  CategoryItem(
    label: 'Voucher',
    icon: Icons.local_offer_rounded,
    iconType: CategoryIconType.voucher,
  ),
  CategoryItem(
    label: 'Lainnya',
    icon: Icons.more_horiz_rounded,
    iconType: CategoryIconType.other,
  ),
];

/// Baris kategori lingkaran besar (60x60) bergaya ilustratif duotone
/// dengan scroll horizontal sehingga 4 item tampil penuh dan item ke-5 mengintip di kanan.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    this.categories = defaultCategories,
    this.onTap,
  });

  final List<CategoryItem> categories;
  final void Function(CategoryItem)? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return _CategoryCircleTile(
            category: cat,
            onTap: () => (cat.onTap ?? () => onTap?.call(cat))(),
          );
        },
      ),
    );
  }
}

class _CategoryCircleTile extends StatelessWidget {
  const _CategoryCircleTile({required this.category, required this.onTap});

  final CategoryItem category;
  final VoidCallback onTap;

  CategoryIconType _resolveType() {
    if (category.iconType != null) return category.iconType!;
    final lower = category.label.toLowerCase();
    if (lower.contains('konser')) return CategoryIconType.concert;
    if (lower.contains('bioskop')) return CategoryIconType.cinema;
    if (lower.contains('olahraga')) return CategoryIconType.sports;
    if (lower.contains('voucher')) return CategoryIconType.voucher;
    return CategoryIconType.other;
  }

  @override
  Widget build(BuildContext context) {
    final type = _resolveType();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CustomPaint(
                    painter: _CategoryDuotonePainter(type),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary.withAlpha(220),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter ikon vektor ilustratif duotone tajam untuk setiap kategori Droptix.
class _CategoryDuotonePainter extends CustomPainter {
  const _CategoryDuotonePainter(this.type);

  final CategoryIconType type;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case CategoryIconType.concert:
        _paintConcert(canvas, size);
        break;
      case CategoryIconType.cinema:
        _paintCinema(canvas, size);
        break;
      case CategoryIconType.sports:
        _paintSports(canvas, size);
        break;
      case CategoryIconType.voucher:
        _paintVoucher(canvas, size);
        break;
      case CategoryIconType.other:
        _paintOther(canvas, size);
        break;
    }
  }

  /// Konser: Headphone / Not Musik panggung duotone (ungu-magenta cerah + highlight).
  void _paintConcert(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final primary = Paint()..color = const Color(0xFFA855F7);
    final secondary = Paint()..color = const Color(0xFFE879F9);
    final dark = Paint()..color = const Color(0xFF581C87);

    // Batang not ganda melengkung
    final beam = Path()
      ..moveTo(w * 0.34, h * 0.24)
      ..lineTo(w * 0.84, h * 0.12)
      ..lineTo(w * 0.84, h * 0.30)
      ..lineTo(w * 0.34, h * 0.42)
      ..close();
    canvas.drawPath(beam, secondary);

    // Tiang kiri & kanan
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, h * 0.24, w * 0.11, h * 0.52),
        const Radius.circular(3),
      ),
      primary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.73, h * 0.14, w * 0.11, h * 0.50),
        const Radius.circular(3),
      ),
      primary,
    );

    // Kepala not kiri & kanan
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.28, h * 0.77),
        width: w * 0.34,
        height: h * 0.24,
      ),
      primary,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.67, h * 0.65),
        width: w * 0.34,
        height: h * 0.24,
      ),
      secondary,
    );

    // Kilau kecil
    canvas.drawCircle(Offset(w * 0.24, h * 0.74), w * 0.045, dark);
    canvas.drawCircle(Offset(w * 0.63, h * 0.62), w * 0.045, dark);
  }

  /// Bioskop: Clapperboard film duotone (biru cerah + strip putih miring).
  void _paintCinema(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final bodyPaint = Paint()..color = const Color(0xFF38BDF8);
    final topPaint = Paint()..color = const Color(0xFF0284C7);
    final stripePaint = Paint()..color = const Color(0xFFE0F2FE);
    final playPaint = Paint()..color = const Color(0xFF082F49);

    // Badan clapperboard
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.08, h * 0.36, w * 0.84, h * 0.54),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      ),
      bodyPaint,
    );

    // Tutup atas miring sedikit
    canvas.save();
    canvas.translate(w * 0.08, h * 0.34);
    canvas.rotate(-0.14);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, -h * 0.22, w * 0.84, h * 0.22),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      ),
      topPaint,
    );
    // 3 strip miring di papan atas
    for (final x in [0.16, 0.44, 0.70]) {
      final p = Path()
        ..moveTo(w * x, -h * 0.22)
        ..lineTo(w * (x + 0.12), -h * 0.22)
        ..lineTo(w * (x + 0.04), 0)
        ..lineTo(w * (x - 0.08), 0)
        ..close();
      canvas.drawPath(p, stripePaint);
    }
    canvas.restore();

    // Segitiga play di tengah badan
    final play = Path()
      ..moveTo(w * 0.43, h * 0.51)
      ..lineTo(w * 0.63, h * 0.63)
      ..lineTo(w * 0.43, h * 0.75)
      ..close();
    canvas.drawPath(play, playPaint);
  }

  /// Olahraga: Piala / Trophy duotone (oranye-emas hangat + aksen gelap).
  void _paintSports(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final cupPaint = Paint()..color = const Color(0xFFFB923C);
    final highlightPaint = Paint()..color = const Color(0xFFFDBA74);
    final basePaint = Paint()..color = const Color(0xFFEA580C);
    final handlePaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;

    // Pegangan kiri & kanan
    canvas.drawArc(
      Rect.fromLTWH(w * 0.06, h * 0.18, w * 0.26, h * 0.30),
      math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.68, h * 0.18, w * 0.26, h * 0.30),
      -math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );

    // Mangkuk piala
    final cup = Path()
      ..moveTo(w * 0.22, h * 0.12)
      ..lineTo(w * 0.78, h * 0.12)
      ..lineTo(w * 0.72, h * 0.48)
      ..quadraticBezierTo(w * 0.50, h * 0.68, w * 0.28, h * 0.48)
      ..close();
    canvas.drawPath(cup, cupPaint);

    // Highlight kiri mangkuk
    final hl = Path()
      ..moveTo(w * 0.28, h * 0.18)
      ..lineTo(w * 0.40, h * 0.18)
      ..lineTo(w * 0.37, h * 0.46)
      ..lineTo(w * 0.30, h * 0.44)
      ..close();
    canvas.drawPath(hl, highlightPaint);

    // Leher & alas piala
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.43, h * 0.58, w * 0.14, h * 0.18),
        const Radius.circular(2),
      ),
      basePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.74, w * 0.50, h * 0.14),
        const Radius.circular(4),
      ),
      cupPaint,
    );
  }

  /// Voucher: Kupon diskon bertakik duotone (hijau-teal cerah + tanda %).
  void _paintVoucher(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final bodyPaint = Paint()..color = const Color(0xFF34D399);
    final stubPaint = Paint()..color = const Color(0xFF059669);
    final cutPaint = Paint()..color = AppColors.surfaceHigh;
    final symbolPaint = Paint()
      ..color = const Color(0xFF064E3B)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Badan kupon utama
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.20, w * 0.88, h * 0.60),
        const Radius.circular(6),
      ),
      bodyPaint,
    );

    // Bagian sobekan kanan (warna lebih pekat)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.68, h * 0.20, w * 0.26, h * 0.60),
        topRight: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      stubPaint,
    );

    // Takik lingkaran kiri & kanan
    canvas.drawCircle(Offset(w * 0.06, h * 0.50), w * 0.09, cutPaint);
    canvas.drawCircle(Offset(w * 0.94, h * 0.50), w * 0.09, cutPaint);

    // Simbol % di sisi kiri
    canvas.drawLine(
      Offset(w * 0.27, h * 0.64),
      Offset(w * 0.53, h * 0.36),
      symbolPaint,
    );
    canvas.drawCircle(Offset(w * 0.30, h * 0.39), 2.3, symbolPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.61), 2.3, symbolPaint);
  }

  /// Lainnya: 4 ubin geometris duotone (teal + aksen cerah).
  void _paintOther(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final primary = Paint()..color = AppColors.primary;
    final soft = Paint()..color = const Color(0xFF2DD4BF).withAlpha(170);

    // 3 kotak membulat + 1 lingkaran di kanan atas
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.33, h * 0.33),
        const Radius.circular(6),
      ),
      primary,
    );
    canvas.drawCircle(
      Offset(w * 0.715, h * 0.285),
      w * 0.165,
      soft,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.55, w * 0.33, h * 0.33),
        const Radius.circular(6),
      ),
      soft,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.55, h * 0.55, w * 0.33, h * 0.33),
        const Radius.circular(6),
      ),
      primary,
    );
  }

  @override
  bool shouldRepaint(covariant _CategoryDuotonePainter oldDelegate) =>
      oldDelegate.type != type;
}
