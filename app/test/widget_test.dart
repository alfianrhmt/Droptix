import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droptix/core/theme/app_colors.dart';
import 'package:droptix/core/widgets/app_background.dart';

void main() {
  testWidgets('AppBackground memakai gradasi token tema', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppBackground(child: SizedBox.expand()),
      ),
    );

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final gradient =
        (box.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors,
        [AppColors.bg, AppColors.glowMid, AppColors.glowEnd]);
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
  });
}
