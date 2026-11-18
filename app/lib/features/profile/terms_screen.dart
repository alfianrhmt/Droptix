import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

/// Halaman statis Syarat Penggunaan Droptix sesuai PRD.md FR-15 dan DESIGN.md Bagian 9b.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
        title: Text('Syarat Penggunaan', style: AppTextStyles.titleMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Syarat & Ketentuan Layanan', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Terakhir diperbarui: November 2026',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSection(
              title: '1. Peran Droptix',
              content:
                  'Droptix adalah platform pasar sekunder (peer-to-peer) yang mempertemukan pemegang tiket konser atau festival yang berhalangan hadir dengan calon pembeli terdekat. Droptix bertindak murni sebagai perantara komunikasi dan tidak menjual tiket secara langsung, serta tidak memberikan jaminan keaslian atas tiket yang diiklankan oleh penjual.',
            ),
            _buildSection(
              title: '2. Larangan Pengguna',
              content:
                  'Pengguna dilarang keras:\n'
                  '• Menjual tiket palsu, kedaluwarsa, atau yang telah dipindahtangankan sebelumnya.\n'
                  '• Melakukan penipuan atau transaksi mencurigakan dalam bentuk apa pun.\n'
                  '• Mengirim spam, iklan berulang, atau pesan otomatis di dalam fitur chat.\n'
                  '• Mengunggah konten atau menunjukkan perilaku yang melanggar hukum, melecehkan, atau tidak pantas.',
            ),
            _buildSection(
              title: '3. Transaksi & Kehati-hatian',
              content:
                  'Kesepakatan transaksi, pembayaran, dan serah terima tiket (baik digital maupun fisik COD) disepakati langsung antara penjual dan pembeli. Pengguna diimbau selalu berhati-hati, memeriksa tiket sebelum melakukan transfer, dan memanfaatkan pertemuan langsung (COD) di tempat ramai yang aman.',
            ),
            _buildSection(
              title: '4. Pelaporan Pelanggaran',
              content:
                  'Jika Anda menemukan listing mencurigakan, tiket terindikasi palsu, atau pengguna yang beritikad buruk, gunakan tombol "Laporkan" pada layar detail listing atau menu titik tiga pada obrolan chat. Tim Droptix akan meninjau setiap laporan dan berhak menyembunyikan listing serta membekukan akun yang melanggar.',
            ),
            _buildSection(
              title: '5. Penghentian & Penghapusan Akun',
              content:
                  'Droptix berhak membatasi, menangguhkan, atau membekukan akun pengguna yang terbukti melanggar ketentuan ini. Untuk permintaan penutupan akun secara sukarela, hubungi kami melalui email bantuan di halo@droptix.app.',
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
