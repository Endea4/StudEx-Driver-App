import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/status.dart';
import '../../core/format.dart';
import '../../providers/debt_provider.dart';

class DebtListScreen extends StatefulWidget {
  const DebtListScreen({super.key});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().fetchDebts();
    });
  }

  Future<void> _confirmPaid(dynamic debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Pembayaran', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary)),
        content: Text('Konfirmasi utang sebesar Rp ${formatMoney(debt.amount)} sudah dibayar?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Sudah Dibayar')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await context.read<DebtProvider>().confirmPaid(debt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Utang berhasil dikonfirmasi' : 'Gagal mengkonfirmasi'),
          backgroundColor: ok ? AppTheme.success : AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Utang'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DebtProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (provider.error != null) {
            return _buildError(
              title: 'Gagal memuat data utang',
              subtitle: provider.error!,
              onRetry: () => provider.fetchDebts(),
            );
          }
          if (provider.activeDebts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text('Tidak ada utang',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('Semua utang sudah lunas',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          final totalActive = provider.activeDebts.fold<double>(0, (sum, debt) => sum + debt.amount);
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.danger.withValues(alpha: 0.15), AppTheme.danger.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total Utang',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('Rp ${formatMoney(totalActive)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.danger, letterSpacing: -0.5)),
                    ]),
                  ),
                  Text('${provider.activeDebts.length} tagihan',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.activeDebts.length,
                  itemBuilder: (context, index) {
                    final debt = provider.activeDebts[index];
                    final ts = '${debt.createdAt.day}/${debt.createdAt.month}/${debt.createdAt.year}';
                    return GestureDetector(
                      onTap: () {
                        if (debt.orderId.isNotEmpty) {
                          Navigator.pushNamed(context, '/trip', arguments: debt.orderId);
                        }
                      },
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long, color: AppTheme.warning, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Rp ${formatMoney(debt.amount)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text('Kode Order ${shortCode(debt.orderNumber.isNotEmpty ? debt.orderNumber : debt.orderId)}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                                if (debt.description.isNotEmpty)
                                  Text(debt.description,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ]),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(ts, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                StatusBadge.payment(debt.status, small: true),
                                const SizedBox(height: 4),
                                const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmPaid(debt),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Konfirmasi Dibayar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError({required String title, required String subtitle, VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger.withValues(alpha: 0.6), size: 56),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
