import 'dart:math' as math;

/// Pilihan kota Indonesia beserta titik koordinat pusat kota.
class CityOption {
  const CityOption({
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String name;
  final double lat;
  final double lng;
}

const List<CityOption> kIndonesianCities = [
  CityOption(name: 'Jakarta', lat: -6.2088, lng: 106.8456),
  CityOption(name: 'Surabaya', lat: -7.2575, lng: 112.7521),
  CityOption(name: 'Bandung', lat: -6.9175, lng: 107.6191),
  CityOption(name: 'Yogyakarta', lat: -7.7956, lng: 110.3695),
  CityOption(name: 'Bali (Denpasar)', lat: -8.6705, lng: 115.2126),
  CityOption(name: 'Medan', lat: 3.5952, lng: 98.6722),
  CityOption(name: 'Semarang', lat: -6.9932, lng: 110.4203),
  CityOption(name: 'Makassar', lat: -5.1477, lng: 119.4327),
  CityOption(name: 'Malang', lat: -7.9666, lng: 112.6326),
  CityOption(name: 'Solo', lat: -7.5755, lng: 110.8243),
  CityOption(name: 'Palembang', lat: -2.9761, lng: 104.7754),
  CityOption(name: 'Balikpapan', lat: -1.2379, lng: 116.8529),
  CityOption(name: 'Bogor', lat: -6.5971, lng: 106.8060),
  CityOption(name: 'Depok', lat: -6.4025, lng: 106.7942),
  CityOption(name: 'Tangerang', lat: -6.1783, lng: 106.6319),
  CityOption(name: 'Bekasi', lat: -6.2383, lng: 106.9756),
];

/// Menghitung jarak Haversine dalam kilometer antara dua koordinat.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * math.pi / 180.0;

/// Mengembalikan kota terdekat dari daftar kota Indonesia jika dalam radius 80 km.
CityOption? findNearestCity(double lat, double lng, {double maxKm = 80}) {
  CityOption? best;
  var bestDist = double.infinity;
  for (final city in kIndonesianCities) {
    final dist = haversineKm(lat, lng, city.lat, city.lng);
    if (dist < bestDist) {
      bestDist = dist;
      best = city;
    }
  }
  if (best != null && bestDist <= maxKm) {
    return best;
  }
  return null;
}

