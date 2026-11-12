'use strict';

/**
 * Normalisasi nomor WhatsApp Indonesia ke format 62xxxxxxxxxx.
 * Contoh: "0812-3456-7890" -> "6281234567890", "+62 812..." -> "62812..."
 * Mengembalikan null jika format tidak valid.
 */
function normalizeWaNumber(raw) {
  if (raw === null || raw === undefined) return null;
  const cleaned = String(raw).replace(/[\s\-().]/g, '');
  if (!cleaned) return null;

  let digits = cleaned;
  if (digits.startsWith('+')) {
    digits = digits.slice(1);
  }
  if (digits.startsWith('0')) {
    digits = `62${digits.slice(1)}`;
  }

  if (!/^62\d{8,13}$/.test(digits)) {
    return null;
  }
  return digits;
}

module.exports = { normalizeWaNumber };
