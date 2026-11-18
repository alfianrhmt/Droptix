'use strict';

/**
 * Bobot komponen relevansi sesuai aturan bisnis BR-5 (docs/PRD.md).
 * Setiap komponen bernilai 0..1:
 * - S_jarak = 1 - min(jarak_km, 20) / 20
 * - S_waktu = 1 - min(sisa_jam, 48) / 48 (sisa_jam = jam menuju waktu_acara)
 * - S_harga = harga_min_event / harga (harga terendah SEMUA listing aktif pada event yang sama)
 * - skor = w_jarak * S_jarak + w_waktu * S_waktu + w_harga * S_harga
 *
 * Disimpan sebagai konstanta di satu berkas agar mudah disetel.
 */
const RELEVANCE_WEIGHTS = {
  last_minute: {
    jarak: 0.45,
    waktu: 0.35,
    harga: 0.20,
  },
  limited: {
    jarak: 0.15,
    waktu: 0.25,
    harga: 0.60,
  },
};

const MAX_JARAK_KM = 20;
const MAX_SISA_JAM = 48;

/**
 * Normalisasi bobot saat pengguna tidak memberikan koordinat (lat/lng).
 * Komponen jarak dibuang dan bobot sisanya dinormalisasi ulang agar berjumlah 1.
 */
function getNormalizedWeights(jenis, hasCoordinates = true) {
  const base = RELEVANCE_WEIGHTS[jenis] || RELEVANCE_WEIGHTS.limited;
  if (hasCoordinates) {
    return {
      jarak: base.jarak,
      waktu: base.waktu,
      harga: base.harga,
    };
  }

  const remainingSum = base.waktu + base.harga;
  return {
    jarak: 0,
    waktu: base.waktu / remainingSum,
    harga: base.harga / remainingSum,
  };
}

function calculateSJarak(jarakKm) {
  if (jarakKm == null || isNaN(jarakKm)) return 0;
  return 1 - Math.min(Math.max(0, jarakKm), MAX_JARAK_KM) / MAX_JARAK_KM;
}

function calculateSWaktu(waktuAcara, now = new Date()) {
  const eventTime = new Date(waktuAcara).getTime();
  const nowTime = new Date(now).getTime();
  const sisaJam = Math.max(0, (eventTime - nowTime) / (3600 * 1000));
  return 1 - Math.min(sisaJam, MAX_SISA_JAM) / MAX_SISA_JAM;
}

function calculateSHarga(harga, hargaMinEvent) {
  if (!harga || harga <= 0) return 0;
  const minHarga = (hargaMinEvent != null && hargaMinEvent > 0) ? hargaMinEvent : harga;
  return Math.min(1, Math.max(0, minHarga / harga));
}

/**
 * Menghitung skor relevansi listing sesuai BR-5.
 */
function computeRelevanceScore({
  jenis,
  harga,
  hargaMinEvent,
  waktuAcara,
  jarakKm = null,
  hasUserLocation = true,
  now = new Date(),
}) {
  const weights = getNormalizedWeights(jenis, hasUserLocation);
  const sJarak = hasUserLocation ? calculateSJarak(jarakKm) : 0;
  const sWaktu = calculateSWaktu(waktuAcara, now);
  const sHarga = calculateSHarga(harga, hargaMinEvent);

  const skor = weights.jarak * sJarak + weights.waktu * sWaktu + weights.harga * sHarga;
  return {
    skor: Math.round(skor * 1000000) / 1000000,
    sJarak,
    sWaktu,
    sHarga,
    weights,
  };
}

/**
 * Membangun klausa ORDER BY SQL untuk skor relevansi sesuai BR-5.
 */
function buildRelevanceSqlOrder({ userLatParamIndex = null, userLngParamIndex = null } = {}) {
  const hasUserLocation = userLatParamIndex != null && userLngParamIndex != null;
  const lm = RELEVANCE_WEIGHTS.last_minute;
  const lim = RELEVANCE_WEIGHTS.limited;

  const minEventPriceSubquery = `(SELECT coalesce(min(l_sub.harga), l.harga) FROM listings l_sub JOIN users u_sub ON u_sub.id = l_sub.seller_id WHERE l_sub.event_id = l.event_id AND l_sub.deleted_at IS NULL AND l_sub.hidden = false AND l_sub.waktu_acara > now() AND (l_sub.jumlah_total - l_sub.jumlah_terjual) > 0 AND u_sub.banned_at IS NULL)`;

  if (hasUserLocation) {
    const haversineFormula = `(6371 * 2 * asin(sqrt(power(sin(radians(l.ref_lat - $${userLatParamIndex}) / 2), 2) + cos(radians($${userLatParamIndex})) * cos(radians(l.ref_lat)) * power(sin(radians(l.ref_lng - $${userLngParamIndex}) / 2), 2))))`;
    const sJarak = `(CASE WHEN l.ref_lat IS NOT NULL AND l.ref_lng IS NOT NULL THEN (1.0 - (LEAST(${haversineFormula}, ${MAX_JARAK_KM}.0) / ${MAX_JARAK_KM}.0)) ELSE 0.0 END)`;
    const sWaktu = `(1.0 - (LEAST(GREATEST(0.0, EXTRACT(EPOCH FROM (l.waktu_acara - now())) / 3600.0), ${MAX_SISA_JAM}.0) / ${MAX_SISA_JAM}.0))`;
    const sHarga = `(LEAST(1.0, ${minEventPriceSubquery}::numeric / l.harga::numeric))`;

    const skorExpr = `(
      (CASE WHEN l.jenis = 'last_minute' THEN ${lm.jarak} ELSE ${lim.jarak} END) * ${sJarak} +
      (CASE WHEN l.jenis = 'last_minute' THEN ${lm.waktu} ELSE ${lim.waktu} END) * ${sWaktu} +
      (CASE WHEN l.jenis = 'last_minute' THEN ${lm.harga} ELSE ${lim.harga} END) * ${sHarga}
    )`;

    return `ORDER BY ${skorExpr} DESC, l.waktu_acara ASC, l.id DESC`;
  } else {
    const lmWaktuNorm = lm.waktu / (lm.waktu + lm.harga);
    const lmHargaNorm = lm.harga / (lm.waktu + lm.harga);
    const limWaktuNorm = lim.waktu / (lim.waktu + lim.harga);
    const limHargaNorm = lim.harga / (lim.waktu + lim.harga);

    const sWaktu = `(1.0 - (LEAST(GREATEST(0.0, EXTRACT(EPOCH FROM (l.waktu_acara - now())) / 3600.0), ${MAX_SISA_JAM}.0) / ${MAX_SISA_JAM}.0))`;
    const sHarga = `(LEAST(1.0, ${minEventPriceSubquery}::numeric / l.harga::numeric))`;

    const skorExpr = `(
      (CASE WHEN l.jenis = 'last_minute' THEN ${lmWaktuNorm} ELSE ${limWaktuNorm} END) * ${sWaktu} +
      (CASE WHEN l.jenis = 'last_minute' THEN ${lmHargaNorm} ELSE ${limHargaNorm} END) * ${sHarga}
    )`;

    return `ORDER BY ${skorExpr} DESC, l.waktu_acara ASC, l.id DESC`;
  }
}

module.exports = {
  RELEVANCE_WEIGHTS,
  MAX_JARAK_KM,
  MAX_SISA_JAM,
  getNormalizedWeights,
  calculateSJarak,
  calculateSWaktu,
  calculateSHarga,
  computeRelevanceScore,
  buildRelevanceSqlOrder,
};
