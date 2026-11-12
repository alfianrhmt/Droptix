import 'package:dio/dio.dart';
import 'package:droptix/core/auth/auth_controller.dart';
import 'package:droptix/core/auth/auth_repository.dart';
import 'package:droptix/core/auth/token_storage.dart';
import 'package:droptix/core/location/cities.dart';
import 'package:droptix/core/location/location_controller.dart';
import 'package:droptix/core/network/api_client.dart';
import 'package:droptix/core/theme/theme.dart';
import 'package:droptix/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocationProvider implements LocationProvider {
  _FakeLocationProvider({
    required this.status,
    this.coords = const DeviceCoordinates(lat: -6.2088, lng: 106.8456),
  });

  LocationAccessStatus status;
  DeviceCoordinates coords;

  @override
  Future<LocationAccessStatus> ensurePermission() async => status;

  @override
  Future<DeviceCoordinates> getCurrentPosition() async => coords;
}

AuthController _makeGuestAuth() {
  final storage = TokenStorage();
  final client = ApiClient(tokenStorage: storage, dio: Dio());
  return AuthController(
    repository: AuthRepository(client),
    tokenStorage: storage,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LocationController memakai GPS saat diizinkan dan menyimpan kota terdekat',
      () async {
    final provider = _FakeLocationProvider(
      status: LocationAccessStatus.granted,
      coords: const DeviceCoordinates(lat: -6.21, lng: 106.84),
    );
    final controller = LocationController(provider: provider);
    await controller.restore();
    expect(controller.hasChosen, isFalse);

    final ok = await controller.requestGpsLocation();
    expect(ok, isTrue);
    expect(controller.city, 'Jakarta');
    expect(controller.isGps, isTrue);
    expect(controller.hasChosen, isTrue);

    final restored = LocationController(provider: provider);
    await restored.restore();
    expect(restored.city, 'Jakarta');
    expect(restored.hasChosen, isTrue);
  });

  test('LocationController menolak GPS dengan pesan jelas dan mendukung pilih kota manual',
      () async {
    final provider = _FakeLocationProvider(status: LocationAccessStatus.denied);
    final controller = LocationController(provider: provider);
    await controller.restore();

    final ok = await controller.requestGpsLocation();
    expect(ok, isFalse);
    expect(controller.errorMessage, contains('Izin lokasi ditolak'));
    expect(controller.hasChosen, isFalse);

    await controller.selectManualCity(
      kIndonesianCities.firstWhere((c) => c.name == 'Bandung'),
    );
    expect(controller.city, 'Bandung');
    expect(controller.isGps, isFalse);
    expect(controller.hasChosen, isTrue);
    expect(controller.errorMessage, isNull);
  });

  testWidgets('Alur izin lokasi ditolak -> fallback pilih kota manual -> ganti dari pil header di 360x740',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _makeGuestAuth();
    await auth.restoreSession();

    final location = LocationController(
      provider: _FakeLocationProvider(status: LocationAccessStatus.denied),
    );
    await location.restore();

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: LocationScope(
          controller: location,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Prompt awal muncul otomatis karena belum memilih lokasi
    expect(find.text('Aktifkan lokasi atau pilih kotamu'), findsOneWidget);

    // Tekan tombol GPS -> ditolak -> tampil pesan fallback
    await tester.tap(find.text('Gunakan lokasi saat ini (GPS)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Izin lokasi ditolak'), findsOneWidget);

    // Pilih kota Bandung secara manual
    await tester.tap(find.text('Bandung'));
    await tester.pumpAndSettle();

    // Pil lokasi di header berubah menjadi Bandung
    expect(find.text('Bandung'), findsOneWidget);

    // Ketuk pil lokasi di header untuk mengganti ke Yogyakarta
    await tester.tap(find.text('Bandung'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih lokasi'), findsOneWidget);

    await tester.tap(find.text('Yogyakarta'));
    await tester.pumpAndSettle();
    expect(find.text('Yogyakarta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
