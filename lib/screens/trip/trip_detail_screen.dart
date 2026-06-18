import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/format.dart';
import '../../core/network/api_client.dart';
import '../../providers/app_provider.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Map<String, dynamic>? _trip;
  List<dynamic> _logs = [];
  List<dynamic> _ratings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<AppProvider>().apiClient;
      final tripRes = await api.get('/trips/${widget.tripId}');
      if (tripRes.statusCode == 200) {
        _trip = jsonDecode(tripRes.body);
      }
      final logsRes = await api.get('/trips/${widget.tripId}/logs');
      if (logsRes.statusCode == 200) {
        _logs = jsonDecode(logsRes.body) ?? [];
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('Trip ${widget.tripId.substring(0, widget.tripId.length > 8 ? 8 : widget.tripId.length)}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _trip == null
              ? const Center(child: Text('Trip tidak ditemukan', style: TextStyle(color: AppTheme.textMuted)))
              : RefreshIndicator(
                  color: AppTheme.accent,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatusHeader(),
                      const SizedBox(height: 16),
                      _buildRouteCard(),
                      const SizedBox(height: 16),
                      _buildPriceCard(),
                      const SizedBox(height: 16),
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildTimeline(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusHeader() {
    final status = _trip?['status'] ?? '';
    final paymentStatus = _trip?['payment_status'] ?? '';
    Color statusColor;
    switch (status) {
      case 'completed': statusColor = AppTheme.success; break;
      case 'cancelled': statusColor = AppTheme.danger; break;
      case 'in_progress': statusColor = AppTheme.accent; break;
      default: statusColor = AppTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              status == 'completed' ? Icons.check_circle : status == 'cancelled' ? Icons.cancel : Icons.directions_bike,
              color: statusColor, size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
                if (paymentStatus.isNotEmpty)
                  Text('Pembayaran: $paymentStatus',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Text(_trip?['service_type']?.toString().toUpperCase() ?? '',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RUTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                  Container(width: 2, height: 32, color: AppTheme.surfaceBorder),
                  const Icon(Icons.location_on, color: AppTheme.danger, size: 16),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_trip?['pickup_lat']?.toStringAsFixed(4) ?? '-'}, ${_trip?['pickup_lng']?.toStringAsFixed(4) ?? '-'}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 20),
                    Text('${_trip?['dest_lat']?.toStringAsFixed(4) ?? '-'}, ${_trip?['dest_lng']?.toStringAsFixed(4) ?? '-'}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    final finalPrice = (_trip?['final_price'] ?? 0).toDouble();
    final bidPrice = (_trip?['current_bid_price'] ?? 0).toDouble();
    final lastBidder = _trip?['last_bidder'] ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HARGA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Harga Akhir', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  Text('Rp ${formatMoney(finalPrice)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Harga Bid', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  Text('Rp ${formatMoney(bidPrice)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  if (lastBidder.isNotEmpty)
                    Text('oleh $lastBidder', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INFO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _infoRow('Trip ID', _trip?['id'] ?? ''),
          _infoRow('Order ID', _trip?['order_id'] ?? ''),
          _infoRow('Customer', _trip?['customer_ref_id'] ?? ''),
          _infoRow('Driver', _trip?['driver_ref_id'] ?? ''),
          _infoRow('Dibuat', _trip?['created_at'] ?? ''),
          _infoRow('Diperbarui', _trip?['updated_at'] ?? ''),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: const Center(child: Text('Belum ada riwayat', style: TextStyle(color: AppTheme.textMuted))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RIWAYAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...(_logs.map((log) => _timelineItem(log))),
      ],
    );
  }

  Widget _timelineItem(dynamic log) {
    final fromState = log['from_state'] ?? '';
    final toState = log['to_state'] ?? '';
    final actor = log['actor'] ?? '';
    final reason = log['reason'] ?? '';
    final ts = log['created_at'] ?? '';
    final tsShort = ts.length > 19 ? ts.substring(0, 19) : ts;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
              Container(width: 2, height: 24, color: AppTheme.surfaceBorder),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$fromState → $toState', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Row(
                  children: [
                    Text(actor, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    if (reason.isNotEmpty) ...[
                      const Text(' · ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      Expanded(child: Text(reason, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
                Text(tsShort, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
