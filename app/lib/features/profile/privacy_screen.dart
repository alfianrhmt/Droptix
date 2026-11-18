import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Halaman statis Kebijakan Privasi Droptix sesuai PRD.md FR-15 dan DESIGN.md Bagian 9b.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Kebijakan Privasi', style: AppTextStyles.titleMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kebijakan Privasi Droptix', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Terakhir diperbarui: November 2026',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSection(
              title: '1. Informasi yang Kami Kumpulkan',
              content:
                  'Kami mengumpulkan informasi yang Anda berikan saat mendaftar dan beraktivitas di Droptix:\n'
                  '• Nama lengkap dan alamat email (untuk identitas akun dan autentikasi).\n'
                  '• Kota domisili (untuk kurasi dan rekomendasi listing terdekat).\n'
                  '• Nomor WhatsApp (opsional, hanya dibagikan kepada calon pembeli jika Anda mengaktifkan opsi "Lanjut via WhatsApp").\n'
                  '• Pesan dan riwayat percakapan di dalam fitur chat Droptix.',
            ),
            _buildSection(
              title: '2. Penggunaan Data Lokasi (GPS)',
              content:
                  'Izin lokasi perangkat digunakan semata-mata untuk mengurutkan listing tiket berdasarkan jarak terdekat dari posisi Anda saat membuka aplikasi. Koordinat GPS Anda dihitung langsung di memori perangkat dan TIDAK PERNAH disimpan permanen di peladen (server) atau basis data kami.',
            ),
            _buildSection(
              title: '3. Perlindungan Privasi Penjual & Pembeli',
              content:
                  'Droptix menjaga privasi kontak Anda. Alamat email dan nomor telepon Anda tidak pernah ditampilkan secara publik pada halaman detail listing. Komunikasi awal selalu berlangsung secara anonim melalui sistem chat dalam aplikasi.',
            ),
            _buildSection(
              title: '4. Penggunaan Data untuk Keamanan & Moderasi',
              content:
                  'Kami menggunakan data akun dan aktivitas pelaporan untuk memantau keamanan platform, menindak indikasi penipuan, menyaring spam, dan menegakkan Syarat Penggunaan Droptix.',
            ),
            _buildSection(
              title: '5. Permintaan Penghapusan Data & Akun',
              content:
                  'Sesuai hak privasi Anda, Anda dapat meminta penghapusan seluruh data pribadi dan akun Droptix Anda. Pada versi ini, permohonan penghapusan akun diproses secara manual dengan mengirimkan email ke halo@droptix.app dari alamat email yang terdaftar.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            content,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
