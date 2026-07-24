import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/status.dart';
import '../../core/format.dart';
import '../../core/geo.dart';
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
        title: Text('Detail Trip ${shortCode(widget.tripId)}'),
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
                    padding: const EdgeInsets.all(AppTheme.space4),
                    children: [
                      _buildStatusHeader(),
                      const SizedBox(height: AppTheme.space4),
                      _buildRouteCard(),
                      const SizedBox(height: AppTheme.space4),
                      _buildPriceCard(),
                      const SizedBox(height: AppTheme.space4),
                      _buildInfoCard(),
                      const SizedBox(height: AppTheme.space4),
                      _buildChatHistoryButton(),
                      const SizedBox(height: AppTheme.space4),
                      _buildTimeline(),
                      const SizedBox(height: AppTheme.space8),
                    ],
                  ),
                ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.danger;
      case 'in_progress':
        return AppTheme.accent;
      default:
        return AppTheme.warning;
    }
  }

  Widget _buildStatusHeader() {
    final status = (_trip?['status'] ?? '').toString();
    final paymentStatus = (_trip?['payment_status'] ?? '').toString();
    final serviceType = (_trip?['service_type'] ?? '').toString();
    final statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              status == 'completed'
                  ? Icons.check_circle
                  : status == 'cancelled'
                      ? Icons.cancel
                      : Icons.directions_bike,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TripStatus.label(status),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: -0.2)),
                if (paymentStatus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Text('Pembayaran',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(width: 6),
                    StatusBadge.payment(paymentStatus, small: true),
                  ]),
                ],
              ],
            ),
          ),
          if (serviceType.isNotEmpty) StatusBadge.service(serviceType),
        ],
      ),
    );
  }

  Widget _cardShell({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.4)),
          const SizedBox(height: AppTheme.space3),
          child,
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    final pl = (_trip?['pickup_lat'] ?? 0).toDouble();
    final plng = (_trip?['pickup_lng'] ?? 0).toDouble();
    final dl = (_trip?['dest_lat'] ?? 0).toDouble();
    final dlng = (_trip?['dest_lng'] ?? 0).toDouble();
    return _cardShell(
      title: 'RUTE',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 3),
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
              Container(width: 2, height: 34, color: AppTheme.surfaceBorder),
              const Icon(Icons.location_on, color: AppTheme.danger, size: 16),
            ],
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jemput', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                AddressText(pl, plng, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.35)),
                const SizedBox(height: AppTheme.space3),
                const Text('Tujuan', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                AddressText(dl, dlng, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    final finalPrice = (_trip?['final_price'] ?? 0).toDouble();
    final bidPrice = (_trip?['current_bid_price'] ?? 0).toDouble();
    final lastBidder = (_trip?['last_bidder'] ?? '').toString();
    return _cardShell(
      title: 'HARGA',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Harga Akhir', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text('Rp ${formatMoney(finalPrice)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accent, letterSpacing: -0.5)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Harga Bid', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text('Rp ${formatMoney(bidPrice)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              if (lastBidder.isNotEmpty)
                Text('oleh $lastBidder', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return _cardShell(
      title: 'INFO',
      child: Column(
        children: [
          _infoRow('Kode Order', shortCode(_trip?['order_id'])),
          _infoRow('Dibuat', _fmtTime(_trip?['created_at'])),
          _infoRow('Diperbarui', _fmtTime(_trip?['updated_at'])),
        ],
      ),
    );
  }

  String _fmtTime(dynamic v) {
    final s = (v ?? '').toString();
    if (s.isEmpty) return '-';
    return formatDateTime(s);
  }

  // Read-only chat history for this trip (bridged conversation with customer).
  Widget _buildChatHistoryButton() {
    final tripId = (_trip?['id'] ?? '').toString();
    if (tripId.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppTheme.brandCyan.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => Navigator.pushNamed(context, '/chat',
            arguments: {'tripId': tripId, 'history': true}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            const Icon(Icons.forum_rounded, color: AppTheme.brandCyanDark),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Lihat Riwayat Chat',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.brandCyanDark)),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.brandCyanDark),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_logs.isEmpty) {
      return _cardShell(
        title: 'RIWAYAT',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text('Belum ada riwayat', style: TextStyle(color: AppTheme.textMuted))),
        ),
      );
    }
    return _cardShell(
      title: 'RIWAYAT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _logs.length; i++) _timelineItem(_logs[i], i == _logs.length - 1),
        ],
      ),
    );
  }

  Widget _timelineItem(dynamic log, bool isLast) {
    final fromState = (log['from_state'] ?? '').toString();
    final toState = (log['to_state'] ?? '').toString();
    final actor = (log['actor'] ?? '').toString();
    final reason = (log['reason'] ?? '').toString();
    final ts = (log['created_at'] ?? '').toString();
    final tsShort = formatDateTime(ts);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 3),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
              if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.surfaceBorder)),
            ],
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fromState.isEmpty ? toState : '$fromState → $toState',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (actor.isNotEmpty)
                        Text(actor, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      if (reason.isNotEmpty) ...[
                        if (actor.isNotEmpty)
                          const Text(' · ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Expanded(
                            child: Text(reason,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                  Text(tsShort, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
