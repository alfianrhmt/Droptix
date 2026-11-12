/// Token jarak (kelipatan 4) dan radius.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Padding horizontal layar.
  static const double screenH = 16;
}

/// Token radius sudut.
abstract final class AppRadius {
  /// Elemen kecil (mis. badge).
  static const double sm = 12;

  /// Input, thumbnail, tombol ikon.
  static const double md = 16;

  /// Poster, banner, kartu besar.
  static const double lg = 20;

  /// Pil penuh (chip, tombol utama, pil lokasi).
  static const double full = 999;
}

/// Area sentuh minimal.
abstract final class AppTouchTarget {
  static const double min = 48;
}

