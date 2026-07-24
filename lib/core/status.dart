import 'package:flutter/material.dart';
import 'theme.dart';

/// Presentation for backend enums (trip status, service type).
///
/// Raw values like `IN_PROGRESS` or `ANJEM` used to be printed straight to the
/// screen. Drivers read Indonesian, not SCREAMING_SNAKE_CASE, so every enum is
/// rendered through here: a readable label plus a consistent colour, so the
/// same state always looks the same wherever it appears.
class TripStatus {
  /// Human label for a trip status, e.g. `in_progress` -> "Berlangsung".
  static String label(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending_acceptance':
        return 'Menunggu Konfirmasi';
      case 'bargaining':
        return 'Negosiasi';
      case 'deal':
        return 'Harga Disetujui';
      case 'accepted':
        return 'Diterima';
      case 'in_progress':
        return 'Berlangsung';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      case 'aborted':
        return 'Dihentikan';
      case 'expired':
        return 'Kedaluwarsa';
      case '':
        return '-';
      default:
        // Unknown value: at least make it readable instead of RAW_ENUM.
        return _titleCase(raw);
    }
  }

  /// Colour used for the badge of a trip status.
  static Color color(String raw) {
    switch (raw.toLowerCase()) {
      case 'completed':
      case 'deal':
        return AppTheme.success;
      case 'in_progress':
      case 'accepted':
        return AppTheme.accent;
      case 'bargaining':
      case 'pending_acceptance':
        return AppTheme.warning;
      case 'rejected':
      case 'cancelled':
      case 'aborted':
      case 'expired':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }
}

/// Payment outcome (`cash`, `debt`, `unpaid`, `paid`) presentation.
class PaymentStatus {
  static String label(String raw) {
    switch (raw.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'paid':
        return 'Lunas';
      case 'debt':
      case 'unpaid':
        return 'Utang';
      case 'earned':
        return 'Pendapatan';
      case '':
        return '-';
      default:
        return _titleCase(raw);
    }
  }

  static Color color(String raw) {
    switch (raw.toLowerCase()) {
      case 'cash':
      case 'paid':
      case 'earned':
        return AppTheme.success;
      case 'debt':
      case 'unpaid':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }
}

/// Service type (`anjem`, `jastip`) presentation.
class ServiceType {
  static String label(String raw) {
    switch (raw.toLowerCase()) {
      case 'anjem':
        return 'Anjem';
      case 'jastip':
        return 'Jastip';
      case '':
        return '-';
      default:
        return _titleCase(raw);
    }
  }

  static Color color(String raw) {
    switch (raw.toLowerCase()) {
      case 'jastip':
        return AppTheme.brandCyanDark;
      default:
        return AppTheme.accent;
    }
  }
}

/// Gender presentation (`male`/`female` -> "Laki-laki"/"Perempuan").
class Gender {
  static String label(String raw) {
    switch (raw.toLowerCase()) {
      case 'male':
      case 'l':
        return 'Laki-laki';
      case 'female':
      case 'p':
        return 'Perempuan';
      case '':
        return '-';
      default:
        return _titleCase(raw);
    }
  }
}

String _titleCase(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// A coloured pill showing an enum value.
///
/// Keeping one widget for this means a status reads the same — same wording,
/// same colour — on the ride, history, detail and rating screens.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.small = false,
  });

  /// Badge for a trip status value straight from the backend.
  factory StatusBadge.trip(String raw, {bool small = false}) => StatusBadge(
        label: TripStatus.label(raw),
        color: TripStatus.color(raw),
        small: small,
      );

  /// Badge for a service type value straight from the backend.
  factory StatusBadge.service(String raw, {bool small = false}) => StatusBadge(
        label: ServiceType.label(raw),
        color: ServiceType.color(raw),
        small: small,
      );

  /// Badge for a payment status value straight from the backend.
  factory StatusBadge.payment(String raw, {bool small = false}) => StatusBadge(
        label: PaymentStatus.label(raw),
        color: PaymentStatus.color(raw),
        small: small,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
