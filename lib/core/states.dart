import 'package:flutter/material.dart';
import 'theme.dart';

/// Full-page error and empty states.
///
/// These replaced a bare red exclamation mark over an unbounded line of text:
/// the message ran the full width of the screen, sat flush against the icon and
/// gave the driver nothing to look at but the failure. Here the message lives
/// inside a contained card with a soft halo icon, a short headline, the detail
/// in secondary text, and the recovery action right below it.
class ErrorState extends StatelessWidget {
  /// Short headline, e.g. "Gagal memuat profil".
  final String title;

  /// Optional detail (the underlying error). Shown smaller and de-emphasised.
  final String? detail;

  final IconData icon;
  final Color color;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.cloud_off_rounded,
    this.color = AppTheme.danger,
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: ConstrainedBox(
          // Keeps the copy at a readable measure instead of stretching edge to
          // edge on a tall phone screen.
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space6,
              vertical: AppTheme.space8,
            ),
            decoration: AppTheme.cardDecoration(radius: AppTheme.radiusXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Halo(icon: icon, color: color),
                const SizedBox(height: AppTheme.space5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    detail!.trim(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: AppTheme.space6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(retryLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-page "nothing here yet" state — same shape as [ErrorState] so the two
/// do not look like they came from different apps.
class EmptyState extends StatelessWidget {
  final String title;
  final String? detail;
  final IconData icon;
  final VoidCallback? onAction;
  final String actionLabel;

  const EmptyState({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.inbox_rounded,
    this.onAction,
    this.actionLabel = 'Muat Ulang',
  });

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: title,
      detail: detail,
      icon: icon,
      color: AppTheme.textMuted,
      onRetry: onAction,
      retryLabel: actionLabel,
    );
  }
}

/// Concentric tinted rings behind the icon — softens the alert without losing
/// the colour signal.
class _Halo extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Halo({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.06),
      ),
      child: Center(
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
