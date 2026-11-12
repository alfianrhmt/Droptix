import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget pembungkus semua layar.
/// Scaffold di atasnya harus [scaffoldBackgroundColor: Colors.transparent].
///
/// Gradasi diagonal kiri-atas → kanan-bawah:
///   - kiri atas  : [AppColors.bg] (sangat gelap)
///   - tengah     : [AppColors.glowMid] (teal samar, sekitar 40%)
///   - kanan bawah: [AppColors.glowEnd] (teal lebih kuat)
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.42, 1.0],
          colors: [
            AppColors.bg,
            AppColors.glowMid,
            AppColors.glowEnd,
          ],
        ),
      ),
      child: child,
    );
  }
}

