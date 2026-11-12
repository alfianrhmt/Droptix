import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';
import 'package:droptix/features/gallery/component_gallery_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child, {double textScale = 1.0}) {
    return CountdownTimerProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: widget!,
        ),
        home: child,
      ),
    );
  }

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
    expect(
      gradient.colors,
      [AppColors.bg, AppColors.glowMid, AppColors.glowEnd],
    );
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
  });

  testWidgets('UnreadBadge menampilkan angka dan 9+ untuk di atas 9',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const Scaffold(
          body: Row(
            children: [
              UnreadBadge(count: 0),
              UnreadBadge(count: 4),
              UnreadBadge(count: 15),
            ],
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('ComponentGallery tampil tanpa overflow di 390x844',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const ComponentGalleryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Droptix'), findsOneWidget);
    expect(find.text('Dekat Kamu'), findsOneWidget);
    expect(find.text('Segera Berakhir'), findsOneWidget);
  });

  testWidgets(
      'ComponentGallery tampil tanpa overflow di 360x740 dengan skala teks 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(const ComponentGalleryScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(find.text('Droptix'), findsOneWidget);
    expect(find.text('Limited'), findsWidgets);
    expect(find.text('Last-Minute'), findsWidgets);
  });
}
