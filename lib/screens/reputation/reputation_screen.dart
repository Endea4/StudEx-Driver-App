import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(title: const Text('Reputasi')),
      body: Consumer<ReputationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }
          final rep = provider.reputation;
          if (rep == null) {
            return const Center(child: Text('Data tidak tersedia'));
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchReputation(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _scoreCard(rep),
                const SizedBox(height: 16),
                Text('Review (${rep.totalReviews})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (rep.reviews.isEmpty)
                  const Center(child: Text('Belum ada review', style: TextStyle(color: Colors.grey)))
                else
                  ...rep.reviews.map((r) => _reviewCard(r)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scoreCard(dynamic rep) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              rep.score.toStringAsFixed(1),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Icon(
                  index < rep.score.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 28,
                );
              }),
            ),
            const SizedBox(height: 8),
            Text('${rep.totalReviews} review', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(dynamic review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(review.raterName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.score ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            if (review.review.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.review, style: const TextStyle(fontSize: 13)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
