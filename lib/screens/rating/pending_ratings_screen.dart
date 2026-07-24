import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/status.dart';
import '../../core/states.dart';
import '../../core/geo.dart';
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
                    Text(
                      (rating.customerName as String).isNotEmpty ? rating.customerName : 'Customer',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    if (rating.hasRoute == true) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle(
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Flexible(child: AddressText(rating.pickupLat, rating.pickupLng, maxLines: 1,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
                          const Text('  →  '),
                          Flexible(child: AddressText(rating.destLat, rating.destLng, maxLines: 1,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
                        ]),
                      ),
                    ],
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
            return ErrorState(
              title: 'Gagal memuat rating',
              detail: provider.error,
              icon: Icons.star_border_rounded,
              onRetry: () => provider.fetchPendingRatings(),
            );
          }
          final pending = provider.pendingRatings.where((r) => !r.driverResponded).toList();
          if (pending.isEmpty) {
            return const EmptyState(
              title: 'Tidak ada rating menunggu',
              detail: 'Semua rating sudah kamu berikan.',
              icon: Icons.star_outline_rounded,
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

  Widget _ratingCard(dynamic rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  (rating.customerName as String).isNotEmpty ? rating.customerName : 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: (rating.serviceType as String).isNotEmpty
                      ? StatusBadge.service(rating.serviceType, small: true)
                      : const StatusBadge(label: 'Selesai', color: AppTheme.success, small: true),
                ),
              ]),
            ),
          ]),
          if (rating.hasRoute == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              child: Column(children: [
                Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: AddressText(rating.pickupLat, rating.pickupLng, maxLines: 1,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, color: AppTheme.danger, size: 12),
                  const SizedBox(width: 4),
                  Expanded(child: AddressText(rating.destLat, rating.destLng, maxLines: 1,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ]),
              ]),
            ),
          ],
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
