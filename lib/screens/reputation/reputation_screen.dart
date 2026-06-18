import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/reputation.dart';
import '../../providers/reputation_provider.dart';

class ReputationScreen extends StatefulWidget {
  const ReputationScreen({super.key});

  @override
  State<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends State<ReputationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReputationProvider>().fetchReputation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Reputasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ReputationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchReputation(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }
          final rep = provider.reputation;
          if (rep == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment_outlined,
                      color: AppTheme.textMuted.withOpacity(0.5), size: 64),
                  const SizedBox(height: 16),
                  const Text('Belum ada data reputasi',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                  const SizedBox(height: 8),
                  const Text('Selesaikan pesanan untuk mendapatkan reputasi',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchReputation(),
            color: AppTheme.accent,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Score hero card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accent.withOpacity(0.15),
                        AppTheme.accent.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        rep.score.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accent,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final fillValue = (rep.score - index).clamp(0.0, 1.0).toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _StarIcon(fill: fillValue, size: 28),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${rep.totalReviews} review',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Reviews section
                if (rep.reviews.isNotEmpty) ...[
                  const SectionHeader(title: 'Review'),
                  ...rep.reviews.map((r) => _reviewCard(r)),
                ] else
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'Belum ada review',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _reviewCard(Review review) {
    final ts =
        '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: AppTheme.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.raterName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  final fillValue = (review.score - index).clamp(0.0, 1.0).toDouble();
                  return _StarIcon(fill: fillValue, size: 16);
                }),
              ),
            ],
          ),
          if (review.review.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.review,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              ts,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarIcon extends StatelessWidget {
  final double fill; // 0.0 to 1.0
  final double size;

  const _StarIcon({required this.fill, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.star_rounded, color: AppTheme.warning.withOpacity(0.25), size: size),
          ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                stops: [fill, fill],
                colors: [AppTheme.warning, AppTheme.warning.withOpacity(0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                tileMode: TileMode.mirror,
              ).createShader(rect);
            },
            child: Icon(Icons.star_rounded, color: AppTheme.warning, size: size),
          ),
        ],
      ),
    );
  }
}
