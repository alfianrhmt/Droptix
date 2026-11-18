'use strict';

/**
 * Menghitung status siklus hidup tiket berdasarkan waktu acara dan ketersediaan stok (BR-2).
 * Kemungkinan: 'tersedia' | 'terjual' | 'kedaluwarsa' | 'dihapus'
 */
function computeListingStatus(row) {
  if (row.deleted_at || row.hidden) return 'dihapus';
  if (new Date(row.waktu_acara).getTime() <= Date.now()) return 'kedaluwarsa';
  if (row.jumlah_total - row.jumlah_terjual <= 0) return 'terjual';
  return 'tersedia';
}

module.exports = {
  computeListingStatus,
};
