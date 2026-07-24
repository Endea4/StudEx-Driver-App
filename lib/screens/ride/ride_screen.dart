import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/theme.dart';
import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/status.dart';
import '../../core/states.dart';
import '../../providers/ride_provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/ride.dart';

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  late RideProvider _provider;
  StreamSubscription? _stateSub;
  final _bidController = TextEditingController();
  final _bidReasonController = TextEditingController();
  RideState _state = RideState.idle;
  RideOffer? _offer;
  ActiveTrip? _trip;
  String? _error;
  bool _loading = false;
  bool _showBid = false;
  List<Map<String, dynamic>> _tripHistory = [];
  bool _loadingTrips = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _provider = RideProvider(app.apiClient, app.wsClient, app.localStorage);
    _provider.addListener(_onProviderChanged);

    final saved = app.getActiveRideState();
    if (saved != null) {
      final st = saved['state'] as String? ?? '';
      final trip = saved['trip'] as Map<String, dynamic>?;
      if (trip != null) {
        if (st == 'bidRequest') {
          _provider.resumeBidRequest(trip);
        } else {
          _provider.resumeActiveTrip(trip);
        }
      }
      return;
    }

    final offer = app.latestRideOffer;
    if (offer != null) {
      _provider.testSimulateOfferFromData(offer);
    }
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() => _loadingTrips = true);
    try {
      final driverId = context.read<AppProvider>().localStorage.getDriverId();
      final res = await context.read<AppProvider>().apiClient.get('/trips/driver/$driverId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() => _tripHistory = data.cast<Map<String, dynamic>>());
        }
      }
    } catch (_) {}
    setState(() => _loadingTrips = false);
  }

  void _onProviderChanged() {
    // A rejected action (e.g. bidding twice in a row) leaves the trip intact,
    // so report it in a snackbar and keep the screen as it is.
    final actionError = _provider.actionError;
    if (actionError != null && mounted) {
      _provider.clearActionError();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(actionError),
          backgroundColor: AppTheme.danger,
        ));
    }
    setState(() {
      _state = _provider.state;
      _offer = _provider.currentOffer;
      _trip = _provider.activeTrip;
      _error = _provider.error;
      _loading = _provider.isLoading;
    });
  }

  @override
  void dispose() {
    final app = context.read<AppProvider>();
    if (_state == RideState.active || _state == RideState.bidRequest || _state == RideState.completed) {
      if (_trip != null) {
        app.saveRideState(_state.name, _trip!.toJson());
      }
    } else {
      app.clearRideState();
    }
    _bidController.dispose();
    _bidReasonController.dispose();
    _provider.removeListener(_onProviderChanged);
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Ride', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_state == RideState.offer)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _showRejectDialog(),
              tooltip: 'Cancel',
            ),
          if (_state == RideState.completed)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _provider.reset();
                context.read<AppProvider>().clearRideState();
                setState(() { _state = RideState.idle; _offer = null; _trip = null; });
              },
              tooltip: 'Tutup',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return ErrorState(
        title: 'Terjadi kesalahan',
        detail: _error,
        onRetry: () {
          setState(() => _error = null);
          _fetchTrips();
        },
      );
    }
    switch (_state) {
      case RideState.idle:
        return _buildIdle();
      case RideState.offer:
        return _buildOffer();
      case RideState.active:
        return _buildActive();
      case RideState.bidRequest:
        return _buildBid();
      case RideState.completed:
        return _buildCompleted();
    }
  }

  Widget _buildIdle() {
    return RefreshIndicator(
      onRefresh: _fetchTrips,
      color: AppTheme.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order stats header
          _buildTripSummary(),
          const SizedBox(height: 20),
          // Trip history list
          const Text('RIWAYAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          if (_loadingTrips)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.accent)))
          else if (_tripHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.only(top: 16),
              decoration: AppTheme.cardDecoration(),
              child: Column(children: [
                const Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 48),
                const SizedBox(height: 12),
                const Text('Belum ada riwayat pesanan', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                const Text('Pesanan baru akan muncul di sini', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ]),
            )
          else
            ..._tripHistory.map((t) => _buildTripTile(t)),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    final counts = <String, int>{};
    for (final t in _tripHistory) {
      final s = t['status'] ?? '';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RINGKASAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatBadge('Menunggu', counts['pending_acceptance'] ?? 0, AppTheme.warning),
            const SizedBox(width: 8),
            _buildStatBadge('Aktif', (counts['accepted'] ?? 0) + (counts['in_progress'] ?? 0), AppTheme.accent),
            const SizedBox(width: 8),
            _buildStatBadge('Selesai', counts['completed'] ?? 0, AppTheme.success),
            const SizedBox(width: 8),
            _buildStatBadge('Ditolak', (counts['rejected'] ?? 0) + (counts['cancelled'] ?? 0), AppTheme.danger),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final status = trip['status'] ?? '';
    final color = _statusColor(status);
    final label = _statusLabel(status);
    final icon = _statusIcon(status);
    final price = (trip['final_price'] ?? 0).toInt();
    final pl = (trip['pickup_lat'] ?? 0).toDouble();
    final plng = (trip['pickup_lng'] ?? 0).toDouble();
    final dl = (trip['dest_lat'] ?? 0).toDouble();
    final dlng = (trip['dest_lng'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusMd),
      child: ListTile(
        onTap: () => _onTripTap(trip),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Text('Rp ${formatMoney(price)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
          ],
        ),
        subtitle: Row(children: [
          const Icon(Icons.place, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 3),
          Expanded(child: AddressText(pl, plng, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
          const Icon(Icons.arrow_right_alt, size: 14, color: AppTheme.textMuted),
          Expanded(child: AddressText(dl, dlng, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
        ]),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_acceptance': case 'bargaining': return AppTheme.warning;
      case 'accepted': case 'in_progress': case 'deal': return AppTheme.accent;
      case 'completed': return AppTheme.success;
      case 'rejected': case 'cancelled': return AppTheme.danger;
      default: return AppTheme.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_acceptance': return 'Menunggu';
      case 'bargaining': return 'Negosiasi';
      case 'accepted': return 'Diterima';
      case 'in_progress': return 'Berjalan';
      case 'deal': return 'Deal';
      case 'completed': return 'Selesai';
      case 'rejected': return 'Ditolak';
      case 'cancelled': return 'Batal';
      default: return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending_acceptance': return Icons.hourglass_empty;
      case 'bargaining': return Icons.gavel;
      case 'accepted': return Icons.check_circle;
      case 'in_progress': return Icons.directions_bike;
      case 'deal': return Icons.handshake;
      case 'completed': return Icons.check_circle_outline;
      case 'rejected': return Icons.close;
      case 'cancelled': return Icons.cancel;
      default: return Icons.info;
    }
  }

  Widget _buildOffer() {
    final offer = _offer!;
    final distance = _calcDistance(offer.pickupLat, offer.pickupLng, offer.destLat, offer.destLng);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMap(offer.pickupLat, offer.pickupLng, offer.destLat, offer.destLng),
        const SizedBox(height: 16),
        _buildInfoCard([
          _addrRow('Jemput', offer.pickupLat, offer.pickupLng),
          _addrRow('Tujuan', offer.destLat, offer.destLng),
          _infoRow('Jarak', '${distance.toStringAsFixed(1)} km'),
          _infoRow('Estimasi Harga', 'Rp ${formatMoney(offer.estimatedPrice.toInt())}'),
          _badgeRow('Layanan', StatusBadge.service(offer.serviceType)),
        ]),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final app = context.read<AppProvider>();
                    final ok = await _provider.acceptOffer();
                    if (ok) app.clearLatestOffer();
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Terima', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(),
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('Tolak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActive() {
    final trip = _trip!;
    final distance = _calcDistance(trip.pickupLat, trip.pickupLng, trip.destLat, trip.destLng);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMap(trip.pickupLat, trip.pickupLng, trip.destLat, trip.destLng),
        const SizedBox(height: 16),
        _buildStatusBanner(trip.status),
        const SizedBox(height: 12),
        _buildInfoCard([
          _badgeRow('Status', StatusBadge.trip(trip.status)),
          _addrRow('Jemput', trip.pickupLat, trip.pickupLng),
          _addrRow('Tujuan', trip.destLat, trip.destLng),
          _infoRow('Jarak', '${distance.toStringAsFixed(1)} km'),
          if (trip.finalPrice > 0) _infoRow('Harga', 'Rp ${formatMoney(trip.finalPrice.toInt())}'),
        ]),
        if (trip.status == 'accepted' || trip.status == 'deal' || trip.status == 'in_progress') ...[
          const SizedBox(height: 12),
          _buildChatButton(trip.id, trip.customerRefId),
        ],
        const SizedBox(height: 24),
        if (trip.status == 'created' || trip.status == 'pending' || trip.status == 'accepted' || trip.status == 'deal') ...[
          _buildActionButton('Mulai Perjalanan', Icons.play_arrow, AppTheme.accent, () => _provider.startTrip()),
          const SizedBox(height: 12),
          if (!_showBid)
            _buildActionButton('Bid Harga', Icons.gavel, AppTheme.warning, () => setState(() => _showBid = true)),
          if (_showBid) ...[
            _buildBidInput(),
            const SizedBox(height: 12),
            TextButton(onPressed: () => setState(() => _showBid = false), child: const Text('Tutup Bid')),
          ],
        ],
        if (trip.status == 'in_progress') ...[
          _buildActionButton('Selesai — Tunai', Icons.money, AppTheme.success, () => _provider.completeTrip(isDebt: false)),
          const SizedBox(height: 12),
          _buildActionButton('Selesai — Utang', Icons.money_off, AppTheme.warning, () => _completeWithDebt(trip.finalPrice)),
        ],
      ],
    );
  }

  Widget _buildChatButton(String tripId, String customerRefId) {
    final chat = context.watch<ChatProvider>();
    final unread = chat.tripId == tripId ? chat.unread : 0;
    return Material(
      color: AppTheme.brandCyan.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => Navigator.pushNamed(context, '/chat', arguments: {
          'tripId': tripId,
          'customerRefId': customerRefId,
        }),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.brandCyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: AppTheme.brandCyanDark, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chat dengan Customer',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brandCyanDark)),
                    SizedBox(height: 2),
                    Text('Terhubung via WhatsApp',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(11)),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.chevron_right, color: AppTheme.brandCyanDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.gavel, color: AppTheme.warning, size: 32),
          const SizedBox(height: 8),
          const Text('Ajukan Bid Harga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: _bidController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Harga bid (Rp)',
              prefixText: 'Rp ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bidReasonController,
            decoration: InputDecoration(
              labelText: 'Alasan (opsional)',
              hintText: 'Contoh: macet, jauh',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_bidController.text) ?? 0;
                if (amount > 0) {
                  _provider.submitBid(amount, reason: _bidReasonController.text);
                  setState(() => _showBid = false);
                  _bidController.clear();
                  _bidReasonController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Kirim Bid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBid() {
    final trip = _trip!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMap(trip.pickupLat, trip.pickupLng, trip.destLat, trip.destLng),
        const SizedBox(height: 16),
        _buildInfoCard([
          _addrRow('Jemput', trip.pickupLat, trip.pickupLng),
          _addrRow('Tujuan', trip.destLat, trip.destLng),
        ]),
        const SizedBox(height: 12),
        _buildBidCard(),
      ],
    );
  }

  Widget _buildBidCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        const Icon(Icons.gavel, color: AppTheme.warning, size: 32),
        const SizedBox(height: 8),
        const Text('Penumpang meminta bid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        if (_trip != null && _trip!.currentBidPrice > 0) ...[
          const SizedBox(height: 8),
          Text('Bid saat ini: Rp ${formatMoney(_trip!.currentBidPrice.toInt())}${_trip!.lastBidder != null ? " oleh ${_trip!.lastBidder}" : ""}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          if (_trip!.reason != null && _trip!.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Alasan: ${_trip!.reason}', style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontStyle: FontStyle.italic)),
          ],
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _bidController, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Harga bid (Rp)', prefixText: 'Rp ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(_bidController.text) ?? 0;
              if (amount > 0) _provider.submitBid(amount, reason: _bidReasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Kirim Bid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: () => _provider.acceptDeal(),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Terima Harga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _buildCompleted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 80),
          const SizedBox(height: 24),
          const Text('Trip Selesai!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          if (_trip != null) ...[
            const SizedBox(height: 8),
            Text('Rp ${formatMoney(_trip!.finalPrice.toInt())}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.accent)),
          ],
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () => setState(() { _state = RideState.idle; _offer = null; _trip = null; }),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Selesai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMap(double pickupLat, double pickupLng, double destLat, double destLng) {
    final pickup = LatLng(pickupLat, pickupLng);
    final dropoff = LatLng(destLat, destLng);
    final center = LatLng((pickupLat + destLat) / 2, (pickupLng + destLng) / 2);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 13),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.studex.driver_app'),
            MarkerLayer(markers: [
              Marker(point: pickup, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 36)),
              Marker(point: dropoff, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color color; String label; IconData icon;
    switch (status) {
      case 'in_progress': color = AppTheme.accent; label = 'Perjalanan Sedang Berlangsung'; icon = Icons.directions_bike; break;
      case 'deal': color = AppTheme.success; label = 'Harga Disetujui'; icon = Icons.handshake; break;
      case 'accepted': color = AppTheme.success; label = 'Pesanan Diterima — Menuju Penjemputan'; icon = Icons.check_circle; break;
      case 'bargaining': color = AppTheme.warning; label = 'Sedang Tawar-menawar'; icon = Icons.gavel; break;
      default:
        // Never show a raw backend status code to the driver; the detail card
        // right below already spells the state out.
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 12), Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color))]),
    );
  }

  void _onTripTap(Map<String, dynamic> trip) {
    final status = trip['status'] ?? '';
    final color = _statusColor(status);
    final label = _statusLabel(status);

    if (status == 'pending_acceptance') {
      _provider.testSimulateOfferFromData({
        'order_id': trip['order_id'] ?? '',
        'pickup_lat': trip['pickup_lat'] ?? 0,
        'pickup_lng': trip['pickup_lng'] ?? 0,
        'dest_lat': trip['dest_lat'] ?? 0,
        'dest_lng': trip['dest_lng'] ?? 0,
        'estimated_price': trip['final_price'] ?? trip['current_bid_price'] ?? 0,
        'score': 0,
        'request_id': trip['request_id'] ?? '',
        'customer_ref_id': trip['customer_ref_id'] ?? '',
        'service_type': trip['service_type'] ?? 'anjem',
        'driver_ref_id': trip['driver_ref_id'] ?? '',
      });
    } else if (status == 'bargaining') {
      _provider.resumeBidRequest({
        'id': trip['id'] ?? '',
        'order_id': trip['order_id'] ?? '',
        'status': status,
        'pickup_lat': trip['pickup_lat'] ?? 0,
        'pickup_lng': trip['pickup_lng'] ?? 0,
        'dest_lat': trip['dest_lat'] ?? 0,
        'dest_lng': trip['dest_lng'] ?? 0,
        'final_price': trip['final_price'] ?? trip['current_bid_price'] ?? 0,
        'current_bid_price': trip['current_bid_price'] ?? 0,
        'last_bidder': trip['last_bidder'] ?? '',
        'reason': trip['reason'] ?? '',
        'service_type': trip['service_type'] ?? 'anjem',
        'driver_ref_id': trip['driver_ref_id'] ?? '',
        'customer_ref_id': trip['customer_ref_id'] ?? '',
      });
    } else if (status == 'accepted' || status == 'in_progress' || status == 'deal') {
      _provider.resumeActiveTrip({
        'id': trip['id'] ?? '',
        'order_id': trip['order_id'] ?? '',
        'status': status,
        'pickup_lat': trip['pickup_lat'] ?? 0,
        'pickup_lng': trip['pickup_lng'] ?? 0,
        'dest_lat': trip['dest_lat'] ?? 0,
        'dest_lng': trip['dest_lng'] ?? 0,
        'final_price': trip['final_price'] ?? trip['current_bid_price'] ?? 0,
        'service_type': trip['service_type'] ?? 'anjem',
        'driver_ref_id': trip['driver_ref_id'] ?? '',
        'customer_ref_id': trip['customer_ref_id'] ?? '',
      });
    } else {
      _showTripDetailDialog(trip, label, color);
    }
  }

  void _showTripDetailDialog(Map<String, dynamic> trip, String label, Color color) {
    final price = (trip['final_price'] ?? 0).toInt();
    final bid = (trip['current_bid_price'] ?? 0).toInt();
    final pl = (trip['pickup_lat'] ?? 0).toDouble();
    final plng = (trip['pickup_lng'] ?? 0).toDouble();
    final dl = (trip['dest_lat'] ?? 0).toDouble();
    final dlng = (trip['dest_lng'] ?? 0).toDouble();
    final ts = trip['updated_at'] ?? trip['created_at'] ?? '';
    final tsShort = formatDateTime(ts);
    final paymentStatus = (trip['payment_status'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Kode Order', shortCode(trip['order_id'])),
            _detailBadgeRow('Status', StatusBadge.trip((trip['status'] ?? '').toString(), small: true)),
            if (paymentStatus.isNotEmpty)
              _detailBadgeRow('Pembayaran', StatusBadge.payment(paymentStatus, small: true)),
            _detailRow('Harga', 'Rp ${formatMoney(price)}'),
            if (bid > 0) _detailRow('Bid', 'Rp ${formatMoney(bid)}'),
            _detailAddrRow('Jemput', pl, plng),
            _detailAddrRow('Tujuan', dl, dlng),
            if (tsShort.isNotEmpty) _detailRow('Waktu', tsShort),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Pesanan'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Alasan menolak (opsional)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _provider.rejectOffer(reason: reasonController.text);
              context.read<AppProvider>().clearLatestOffer();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: AppTheme.cardDecoration(),
    child: Column(children: rows),
  );

  // Row whose value is an enum, shown as a coloured badge rather than a raw
  // backend token like IN_PROGRESS.
  Widget _badgeRow(String label, Widget badge) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      badge,
    ]),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    ]),
  );

  // Row showing a reverse-geocoded place name for a coordinate.
  Widget _addrRow(String label, double lat, double lng) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))),
      Expanded(
        child: AddressText(lat, lng,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ),
    ]),
  );

  // Complete as debt: prompt for the owed amount (default = trip price).
  Future<void> _completeWithDebt(double defaultAmount) async {
    final ctrl = TextEditingController(
        text: defaultAmount > 0 ? defaultAmount.toInt().toString() : '');
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selesai — Utang'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Berapa jumlah utang penumpang?', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Jumlah utang (Rp)', prefixText: 'Rp '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      await _provider.completeTrip(isDebt: true, debtAmount: amount);
    }
  }
  // Detail row whose value is an enum badge instead of raw text.
  Widget _detailBadgeRow(String label, Widget badge) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))),
      badge,
    ]),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontFamily: 'monospace'))),
    ]),
  );

  Widget _detailAddrRow(String label, double lat, double lng) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
      Expanded(child: AddressText(lat, lng, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
    ]),
  );

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
  );

  double _calcDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
