import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Beri Rating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${rating.customerName} - ${rating.serviceType}'),
              const SizedBox(height: 8),
              Text('${rating.origin} → ${rating.destination}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedScore ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () => setDialogState(() => selectedScore = index + 1),
                  );
                }),
              ),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  hintText: 'Review (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim')),
          ],
        ),
      ),
    );

    if (submitted == true && mounted) {
      await context.read<RatingProvider>().submitRating(
            rating.id,
            selectedScore,
            review: reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
          );
    }

    reviewController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rating Menunggu')),
      body: Consumer<RatingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }
          final pending = provider.pendingRatings.where((r) => !r.driverResponded).toList();
          if (pending.isEmpty) {
            return const Center(child: Text('Tidak ada rating yang menunggu'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              return _ratingCard(pending[index]);
            },
          );
        },
      ),
    );
  }

  Widget _ratingCard(dynamic rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(rating.customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(rating.serviceType.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.circle, size: 10, color: Colors.green),
                const SizedBox(width: 8),
                Text(rating.origin, style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Text(rating.destination, style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRatingDialog(rating),
                icon: const Icon(Icons.star_rate),
                label: const Text('Beri Rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
