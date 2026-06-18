import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/rating_provider.dart';

class PendingRatingsScreen extends StatefulWidget {
  const PendingRatingsScreen({super.key});

  @override
  State<PendingRatingsScreen> createState() => _PendingRatingsScreenState();
}

class _PendingRatingsScreenState extends State<PendingRatingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatingProvider>().fetchPendingRatings();
    });
  }

  Future<void> _showRatingDialog(dynamic rating) async {
    int selectedScore = 5;
    final reviewController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Beri Rating',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(rating.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${rating.serviceType} · ${rating.origin} → ${rating.destination}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        textAlign: TextAlign.center),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedScore = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedScore ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppTheme.warning, size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: reviewController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Review (opsional)',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true, fillColor: AppTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Kirim'),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted == true && mounted) {
      await context.read<RatingProvider>().submitRating(
            rating.id, selectedScore,
            review: reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
          );
    }
    reviewController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Rating Menunggu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<RatingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (provider.error != null) {
            return _buildError(
              title: 'Gagal memuat rating',
              subtitle: provider.error!,
              onRetry: () => provider.fetchPendingRatings(),
            );
          }
          final pending = provider.pendingRatings.where((r) => !r.driverResponded).toList();
          if (pending.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_outline_rounded, color: AppTheme.textMuted.withOpacity(0.4), size: 64),
                    const SizedBox(height: 20),
                    const Text('Tidak ada rating menunggu',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Semua rating sudah diberikan',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.accent,
            onRefresh: () => provider.fetchPendingRatings(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (context, index) => _ratingCard(pending[index]),
            ),
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
            Icon(Icons.star_outline_rounded, color: AppTheme.danger.withOpacity(0.6), size: 56),
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

  Widget _ratingCard(dynamic rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rating.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(rating.serviceType.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(rating.origin, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on, color: AppTheme.danger, size: 12),
                const SizedBox(width: 4),
                Expanded(child: Text(rating.destination, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRatingDialog(rating),
              icon: const Icon(Icons.star_rate_rounded, size: 18),
              label: const Text('Beri Rating'),
            ),
          ),
        ],
      ),
    );
  }
}
