import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'countdown_timer.dart';

// ---------------------------------------------------------------------------
// UnreadBadge
// ---------------------------------------------------------------------------

/// Lingkaran merah dengan angka. Tampilkan "9+" untuk angka > 9.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AppColors.urgent,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CountdownBadge
// ---------------------------------------------------------------------------

/// Format waktu sesuai DESIGN.md:
/// - < 3 jam   → "2j 15m lagi"
/// - Hari ini  → "Hari ini 19.30"
/// - Lainnya   → "Sab, 14 Feb"
class CountdownBadge extends StatelessWidget {
  const CountdownBadge({super.key, required this.eventDate});

  final DateTime eventDate;

  String _format(DateTime now) {
    final diff = eventDate.difference(now);
    if (diff.isNegative) return _dayLabel(now);
    if (diff.inHours < 3) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (h > 0) return '${h}j ${m}m lagi';
      return '${m}m lagi';
    }
    final today = DateTime(now.year, now.month, now.day);
    final evDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    if (evDay == today) {
      final hh = eventDate.hour.toString().padLeft(2, '0');
      final mm = eventDate.minute.toString().padLeft(2, '0');
      return 'Hari ini $hh.$mm';
    }
    return _dayLabel(now);
  }

  String _dayLabel(DateTime now) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final d = days[eventDate.weekday - 1];
    final m = months[eventDate.month - 1];
    return '$d, ${eventDate.day} $m';
  }

  @override
  Widget build(BuildContext context) {
    // Coba ambil timer bersama; fallback ke DateTime.now() jika tidak ada.
    DateTime now;
    try {
      now = CountdownTimer.of(context).now;
    } catch (_) {
      now = DateTime.now();
    }
    return Text(
      _format(now),
      style: AppTextStyles.caption.copyWith(color: AppColors.urgent),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// TypeBadge
// ---------------------------------------------------------------------------

enum TicketType { limited, lastMinute }

/// Badge jenis tiket: Limited (outline primary) atau Last-Minute (teks + isi urgent 15%).
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final TicketType type;

  @override
  Widget build(BuildContext context) {
    if (type == TicketType.limited) {
      return _PillBadge(
        label: 'Limited',
        textColor: AppColors.primary,
        borderColor: AppColors.primary,
        bgColor: Colors.transparent,
      );
    }
    return _PillBadge(
      label: 'Last-Minute',
      textColor: AppColors.urgent,
      borderColor: Colors.transparent,
      bgColor: AppColors.urgent.withAlpha(38), // 15%
    );
  }
}

// ---------------------------------------------------------------------------
// ListingStatusBadge (Tersedia, Terjual, Kedaluwarsa)
// ---------------------------------------------------------------------------

class ListingStatusBadge extends StatelessWidget {
  const ListingStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status.toLowerCase()) {
      case 'terjual':
        return const _PillBadge(
          label: 'Terjual',
          textColor: AppColors.textSecondary,
          borderColor: AppColors.divider,
          bgColor: Colors.transparent,
        );
      case 'kedaluwarsa':
        return _PillBadge(
          label: 'Kedaluwarsa',
          textColor: AppColors.urgent,
          borderColor: AppColors.urgent,
          bgColor: AppColors.urgent.withAlpha(38),
        );
      case 'tersedia':
      default:
        return const _PillBadge(
          label: 'Tersedia',
          textColor: AppColors.primary,
          borderColor: AppColors.primary,
          bgColor: Colors.transparent,
        );
    }
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.textColor,
    required this.borderColor,
    required this.bgColor,
  });

  final String label;
  final Color textColor;
  final Color borderColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: textColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeutralChip (abu-abu: Digital / Fisik, seksi tiket)
// ---------------------------------------------------------------------------

class NeutralChip extends StatelessWidget {
  const NeutralChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.chipInactive,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DiscountBadge (teks success, mis. "-40%")
// ---------------------------------------------------------------------------

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();
    return Text(
      '-$percent%',
      style: AppTextStyles.label.copyWith(color: AppColors.success),
    );
  }
}

