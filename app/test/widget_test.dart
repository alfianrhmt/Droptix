import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/core/widgets/widgets.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return CountdownTimerProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: AppBackground(
          child: Scaffold(body: child),
        ),
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
        const Row(
          children: [
            UnreadBadge(count: 0),
            UnreadBadge(count: 4),
            UnreadBadge(count: 15),
          ],
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('Komponen utama tampil tanpa overflow di lebar 360',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final sampleListing = ListingData(
      id: '1',
      eventName: 'Nada Senja Live in Surabaya',
      venueName: 'Grand City Convention Hall',
      city: 'Surabaya',
      eventDate: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
      pricePerTicket: 500000,
      ticketCount: 2,
      distanceKm: 1.2,
      type: TicketType.lastMinute,
      isSaved: true,
    );

    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: Column(
            children: [
              const AppHeader(city: 'Surabaya'),
              const AppSearchBar(readOnly: true),
              const SizedBox(height: AppSpacing.md),
              const ResellTypeTiles(),
              const SizedBox(height: AppSpacing.md),
              const QuickDateGrid(),
              const SizedBox(height: AppSpacing.md),
              const CategoryRow(),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Dekat Kamu'),
              PosterCard(listing: sampleListing),
              ListingRow(listing: sampleListing),
              FilterChipRow(chips: defaultFilterChips(activeLabels: {'Jenis'})),
              const StatsCard(
                stats: [
                  StatItem(value: '2', label: 'Tersedia'),
                  StatItem(value: '1', label: 'Terjual'),
                  StatItem(value: '5', label: 'Tertarik'),
                ],
              ),
              const PrimaryButton(label: 'Chat dengan penjual'),
              const ChatBubble(
                message: 'Halo, masih tersedia?',
                isSelf: true,
                status: MessageSendStatus.sending,
              ),
              const ChatBubble(
                message: 'Gagal kirim',
                isSelf: true,
                status: MessageSendStatus.failed,
              ),
              const ChatInput(),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Droptix'), findsOneWidget);
    expect(find.text('Rp 500.000'), findsWidgets);
    expect(find.textContaining('1,2 km'), findsWidgets);
    expect(find.text('Mengirim…'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
}
