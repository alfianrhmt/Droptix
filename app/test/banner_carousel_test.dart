import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droptix/core/widgets/banner_carousel.dart';
import 'package:droptix/features/events/event_models.dart';

void main() {
  testWidgets('BannerCarousel menampilkan banner standard & hype triptych tanpa overflow di 360x740', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final standardBanner = const AppBanner(
      id: 1,
      type: 'standard',
      badge: 'TIKET RESELL',
      title: 'Kalah War Tiket? Cari Tiket Tangan Kedua di Sini',
      subtitle: 'Beli tiket konser & festival yang sudah sold out.',
      ctaLabel: 'Cari Tiket Konser',
      targetType: 'category',
      targetPayload: 'konser-festival',
      imageUrl: 'https://example.com/banner1.jpg',
    ).toBannerItem();

    final hypeBanner = const AppBanner(
      id: 2,
      type: 'hype_triptych',
      badge: '🔥 SEDANG RAMAI',
      title: 'Tiket Paling Diburu Minggu Ini',
      subtitle: 'Banyak tiket baru masuk.',
      ctaLabel: 'Lihat Semua Event',
      targetType: 'search',
      targetPayload: 'trending',
      posters: [
        BannerPosterSummary(id: 1, nama: 'Coldplay', posterUrl: 'https://example.com/coldplay.jpg'),
        BannerPosterSummary(id: 2, nama: 'Sheila on 7', posterUrl: 'https://example.com/sheila.jpg'),
        BannerPosterSummary(id: 3, nama: 'Pestapora', posterUrl: 'https://example.com/pestapora.jpg'),
      ],
    ).toBannerItem();

    BannerItem? tappedItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerCarousel(
            items: [standardBanner, hypeBanner],
            onTap: (item) => tappedItem = item,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pastikan teks banner standard muncul
    expect(find.text('TIKET RESELL'), findsOneWidget);
    expect(find.text('Kalah War Tiket? Cari Tiket Tangan Kedua di Sini'), findsOneWidget);
    expect(find.text('Cari Tiket Konser'), findsOneWidget);

    // Ketuk banner pertama
    await tester.tap(find.text('Cari Tiket Konser'));
    await tester.pumpAndSettle();
    expect(tappedItem, isNotNull);
    expect(tappedItem?.eventName, equals('Kalah War Tiket? Cari Tiket Tangan Kedua di Sini'));

    // Geser ke banner kedua (hype triptych)
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('🔥 SEDANG RAMAI'), findsOneWidget);
    expect(find.text('Tiket Paling Diburu Minggu Ini'), findsOneWidget);
    expect(find.text('Lihat Semua Event'), findsOneWidget);
  });
}
