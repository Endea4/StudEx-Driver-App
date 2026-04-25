import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Utang')),
      body: Consumer<DebtProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }
          if (provider.activeDebts.isEmpty) {
            return const Center(child: Text('Tidak ada utang aktif'));
          }
          return Column(
            children: [
              _summaryCard(provider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: provider.activeDebts.length,
                  itemBuilder: (context, index) {
                    return _debtCard(provider.activeDebts[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(DebtProvider provider) {
    final totalActive = provider.activeDebts.fold<int>(
      0, (sum, debt) => sum + debt.amount,
    );
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Utang Aktif', style: TextStyle(fontSize: 14)),
            Text(
              'Rp $totalActive',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _debtCard(dynamic debt) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.red),
        title: Text('Rp ${debt.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Order: ${debt.orderId}'),
        trailing: Text(
          '${debt.createdAt.day}/${debt.createdAt.month}/${debt.createdAt.year}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}
