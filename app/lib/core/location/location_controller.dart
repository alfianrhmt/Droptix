import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cities.dart';

enum LocationAccessStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class DeviceCoordinates {
  const DeviceCoordinates({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Abstraksi penyedia lokasi GPS agar mudah diuji tanpa channel perangkat asli.
abstract class LocationProvider {
  Future<LocationAccessStatus> ensurePermission();
  Future<DeviceCoordinates> getCurrentPosition();
}

class GeolocatorLocationProvider implements LocationProvider {
  @override
  Future<LocationAccessStatus> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationAccessStatus.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return LocationAccessStatus.denied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAccessStatus.deniedForever;
    }
    return LocationAccessStatus.granted;
  }

  @override
  Future<DeviceCoordinates> getCurrentPosition() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return DeviceCoordinates(lat: pos.latitude, lng: pos.longitude);
  }
}

/// Mengelola lokasi aktif pengguna (GPS atau pilih kota manual) + persistensi lokal.
class LocationController extends ChangeNotifier {
  LocationController({LocationProvider? provider})
      : _provider = provider ?? GeolocatorLocationProvider();

  static const _keyCity = 'droptix_location_city';
  static const _keyLat = 'droptix_location_lat';
  static const _keyLng = 'droptix_location_lng';
  static const _keyIsGps = 'droptix_location_is_gps';
  static const _keyHasChosen = 'droptix_location_has_chosen';

  final LocationProvider _provider;

  String _city = 'Surabaya';
  double? _lat = -7.2575;
  double? _lng = 112.7521;
  bool _isGps = false;
  bool _hasChosen = false;
  bool _isRestoring = true;
  bool _isLocating = false;
  String? _errorMessage;

  String get city => _city;
  double? get lat => _lat;
  double? get lng => _lng;
  bool get isGps => _isGps;
  bool get hasChosen => _hasChosen;
  bool get isRestoring => _isRestoring;
  bool get isLocating => _isLocating;
  String? get errorMessage => _errorMessage;

  Future<void> restore() async {
    _isRestoring = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(_keyCity);
      if (savedCity != null && savedCity.isNotEmpty) {
        _city = savedCity;
        _lat = prefs.getDouble(_keyLat);
        _lng = prefs.getDouble(_keyLng);
        _isGps = prefs.getBool(_keyIsGps) ?? false;
      }
      _hasChosen = prefs.getBool(_keyHasChosen) ?? false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Meminta izin GPS dan mengambil koordinat. Mengembalikan false jika ditolak/gagal
  /// sehingga UI otomatis mengarahkan pengguna ke pilihan kota manual.
  Future<bool> requestGpsLocation() async {
    _isLocating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _provider.ensurePermission();
      if (status != LocationAccessStatus.granted) {
        _errorMessage = switch (status) {
          LocationAccessStatus.serviceDisabled =>
            'Layanan lokasi (GPS) mati. Pilih kota kamu secara manual di bawah.',
          LocationAccessStatus.deniedForever =>
            'Izin lokasi diblokir permanen. Pilih kota kamu secara manual di bawah.',
          _ => 'Izin lokasi ditolak. Pilih kota kamu secara manual di bawah.',
        };
        return false;
      }

      final coords = await _provider.getCurrentPosition();
      final nearest = findNearestCity(coords.lat, coords.lng);
      _city = nearest?.name ?? 'Lokasi saya';
      _lat = coords.lat;
      _lng = coords.lng;
      _isGps = true;
      _hasChosen = true;
      _errorMessage = null;
      await _persist();
      return true;
    } catch (_) {
      _errorMessage =
          'Gagal mengambil lokasi GPS. Pilih kota kamu secara manual di bawah.';
      return false;
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  Future<void> selectManualCity(CityOption option) async {
    _city = option.name;
    _lat = option.lat;
    _lng = option.lng;
    _isGps = false;
    _hasChosen = true;
    _errorMessage = null;
    notifyListeners();
    await _persist();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCity, _city);
    if (_lat != null) await prefs.setDouble(_keyLat, _lat!);
    if (_lng != null) await prefs.setDouble(_keyLng, _lng!);
    await prefs.setBool(_keyIsGps, _isGps);
    await prefs.setBool(_keyHasChosen, _hasChosen);
  }
}

/// Menyediakan [LocationController] ke seluruh subtree widget.
class LocationScope extends InheritedNotifier<LocationController> {
  const LocationScope({
    super.key,
    required LocationController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocationScope>();
    assert(scope != null, 'LocationScope tidak ditemukan di widget tree.');
    return scope!.notifier!;
  }

  static LocationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LocationScope>()
        ?.notifier;
  }
}
