import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../core/theme.dart';
import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/status.dart';
import '../../core/states.dart';
import '../../providers/ride_provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/ride.dart';
import '../../services/location_service.dart';
import '../../core/storage/local_storage.dart';
import 'trip_detail_screen.dart';

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
  // Both floating panels are collapsible so the map stays the dominant
  // element. The top card (pure info -- status/address/price) starts
  // collapsed since the map already shows pickup/dest/route visually; the
  // bottom sheet (contains actionable buttons) starts expanded so nothing
  // actionable is hidden by default.
  bool _topCardExpanded = false;
  bool _bottomSheetExpanded = true;
  List<Map<String, dynamic>> _tripHistory = [];
  bool _loadingTrips = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    // RideProvider is a top-level, app-lifetime provider (see main.dart) so
    // its WS subscription survives navigation instead of dying with this
    // screen — grab the shared instance rather than constructing a new one.
    _provider = context.read<RideProvider>();
    _provider.addListener(_onProviderChanged);
    _state = _provider.state;
    _offer = _provider.currentOffer;
    _trip = _provider.activeTrip;
    _error = _provider.error;
    _loading = _provider.isLoading;
    _tripHistory = _provider.tripHistory;
    _loadingTrips = _provider.isLoadingTrips;

    // Backfill an offer that arrived while this screen wasn't mounted, but
    // only if the shared provider hasn't already moved past it (e.g. it was
    // accepted/rejected elsewhere) — otherwise this would regress live state
    // back to a stale offer.
    if (_state == RideState.idle) {
      final offer = app.latestRideOffer;
      if (offer != null) {
        _provider.testSimulateOfferFromData(offer);
      }
    }
    _fetchTrips();
  }

  Future<void> _fetchTrips() => _provider.fetchTrips();

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
      _tripHistory = _provider.tripHistory;
      _loadingTrips = _provider.isLoadingTrips;
    });
  }

  @override
  void dispose() {
    _bidController.dispose();
    _bidReasonController.dispose();
    _provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  // The map states (offer/active/bid) go fullscreen -- map fills the whole
  // screen and the AppBar floats transparently over it, mirroring
  // user-web-temp/index.html's layout (fullscreen map + floating overlays)
  // instead of the old scrolling list of stacked cards below a fixed map.
  bool get _isMapState =>
      _state == RideState.offer || _state == RideState.active || _state == RideState.bidRequest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBodyBehindAppBar: _isMapState,
      appBar: AppBar(
        backgroundColor: _isMapState ? Colors.transparent : null,
        title: _isMapState ? null : const Text('Ride', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: _isMapState
            ? _floatingAppBarIcon(Icons.arrow_back_ios_new, () => Navigator.pop(context))
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (_state == RideState.offer)
            _isMapState
                ? _floatingAppBarIcon(Icons.close, () => _showRejectDialog(), tooltip: 'Cancel')
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _showRejectDialog(),
                    tooltip: 'Cancel',
                  ),
          if (_state == RideState.completed)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _provider.reset(),
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
      case RideState.expired:
        return _buildExpired();
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
    return Stack(
      children: [
        Positioned.fill(
          child: _LiveTripMap(pickupLat: offer.pickupLat, pickupLng: offer.pickupLng, destLat: offer.destLat, destLng: offer.destLng, status: null),
        ),
        _floatingTopCard(
          context,
          [
            _addrRow('Jemput', offer.pickupLat, offer.pickupLng),
            _addrRow('Tujuan', offer.destLat, offer.destLng),
            _infoRow('Jarak', '${distance.toStringAsFixed(1)} km'),
            _infoRow('Estimasi Harga', 'Rp ${formatMoney(offer.estimatedPrice.toInt())}'),
            _badgeRow('Layanan', StatusBadge.service(offer.serviceType)),
          ],
          collapsedSummary: Text(
            'Rp ${formatMoney(offer.estimatedPrice.toInt())} · ${distance.toStringAsFixed(1)} km',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ),
        _floatingBottomSheet(context, [
          _buildOfferCountdown(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final app = context.read<AppProvider>();
                      // Either accepted (offer consumed) or found gone
                      // server-side (offer stale) — both mean the cached
                      // copy must never be replayed again.
                      await _provider.acceptOffer();
                      app.clearLatestOffer();
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
        ]),
      ],
    );
  }

  /// Countdown bar for the offer response window (mirrors the trip-service's
  /// 180s "ignored by driver" timeout). Turns red under 30s.
  Widget _buildOfferCountdown() {
    final left = _provider.offerSecondsLeft;
    final total = _provider.offerTimeoutSeconds;
    final frac = total > 0 ? left / total : 0.0;
    final urgent = left <= 30;
    final color = urgent ? AppTheme.danger : AppTheme.accent;
    final mm = (left ~/ 60).toString();
    final ss = (left % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Text('Sisa waktu menjawab', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const Spacer(),
            Text('$mm:$ss', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: AppTheme.surfaceBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  /// Shown when the offer window closed before the driver answered (or the
  /// order was taken/cancelled). Replaces the old dead-end where the stale
  /// offer stayed on screen and accepting it errored "Trip tidak ditemukan".
  Widget _buildExpired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_outlined, size: 44, color: AppTheme.danger),
            ),
            const SizedBox(height: 20),
            const Text('Pesanan Kedaluwarsa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Waktu menjawab habis atau pesanan sudah tidak tersedia. Pesanan berikutnya akan muncul otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<AppProvider>().clearLatestOffer();
                  _provider.reset();
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mengerti'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActive() {
    final trip = _trip!;
    final distance = _calcDistance(trip.pickupLat, trip.pickupLng, trip.destLat, trip.destLng);
    return Stack(
      children: [
        Positioned.fill(
          child: _LiveTripMap(pickupLat: trip.pickupLat, pickupLng: trip.pickupLng, destLat: trip.destLat, destLng: trip.destLng, status: trip.status),
        ),
        _floatingTopCard(
          context,
          [
            _buildStatusBanner(trip.status),
            const SizedBox(height: 10),
            _badgeRow('Status', StatusBadge.trip(trip.status)),
            _autoCancelRow(trip),
            _addrRow('Jemput', trip.pickupLat, trip.pickupLng),
            _addrRow('Tujuan', trip.destLat, trip.destLng),
            _infoRow('Jarak', '${distance.toStringAsFixed(1)} km'),
            if (trip.finalPrice > 0) _infoRow('Harga', 'Rp ${formatMoney(trip.finalPrice.toInt())}'),
          ],
          collapsedSummary: Row(
            children: [
              StatusBadge.trip(trip.status),
              if (trip.finalPrice > 0) ...[
                const SizedBox(width: 8),
                Text('Rp ${formatMoney(trip.finalPrice.toInt())}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ],
            ],
          ),
        ),
        _floatingBottomSheet(context, [
          if (trip.status == 'accepted' || trip.status == 'deal' || trip.status == 'in_progress') ...[
            _buildChatButton(trip.id, trip.customerRefId),
            const SizedBox(height: 12),
          ],
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
          if (trip.status == 'accepted' || trip.status == 'deal' || trip.status == 'in_progress') ...[
            const SizedBox(height: 12),
            _buildActionButton('Batalkan Trip', Icons.cancel_outlined, AppTheme.danger, _showAbortDialog),
          ],
        ]),
      ],
    );
  }

  // Compact single-row chat entry point -- was a taller two-line card with
  // a subtitle, shrunk so it doesn't crowd the floating bottom sheet and
  // leaves more of the map visible.
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_rounded, color: AppTheme.brandCyanDark, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Chat dengan Customer',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.brandCyanDark)),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(9)),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.chevron_right, color: AppTheme.brandCyanDark, size: 18),
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
    return Stack(
      children: [
        Positioned.fill(
          child: _LiveTripMap(pickupLat: trip.pickupLat, pickupLng: trip.pickupLng, destLat: trip.destLat, destLng: trip.destLng, status: trip.status),
        ),
        _floatingTopCard(context, [
          _addrRow('Jemput', trip.pickupLat, trip.pickupLng),
          _addrRow('Tujuan', trip.destLat, trip.destLng),
          _autoCancelRow(trip),
        ]),
        _floatingBottomSheet(context, [
          // Chat was only wired into _buildActive() (accepted/deal/in_progress)
          // -- during bargaining the driver had no way to message the customer
          // at all, even though the chat room is already open by this point
          // (it opens on trip.accepted, and bidding only happens after accept).
          _buildChatButton(trip.id, trip.customerRefId),
          const SizedBox(height: 12),
          _buildBidCard(),
        ]),
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
              onPressed: () => _provider.reset(),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Selesai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
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
      // Completed/rejected/cancelled trips have nothing left to resume into
      // a live screen for -- show a static pickup/dest map instead of the
      // old text-only modal.
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)));
    }
  }

  /// Auto-cancel countdown (ticked by RideProvider's 1s timer; deadline is the
  /// backend's auto_cancel_at, so this always matches what the server enforces).
  Widget _autoCancelRow(ActiveTrip trip) {
    if (trip.autoCancelAt == null) return const SizedBox.shrink();
    final left = _provider.autoCancelSecondsLeft;
    if (left <= 0) return const SizedBox.shrink();
    return _infoRow('Auto-batal', 'dalam ${_formatCountdown(left)} bila tidak ada aksi');
  }

  String _formatCountdown(int s) {
    if (s >= 3600) return '${s ~/ 3600} jam ${(s % 3600) ~/ 60} mnt';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _showAbortDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Trip yang sudah berjalan akan dibatalkan dan customer diberi tahu.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Alasan membatalkan (opsional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kembali')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim();
              _provider.abortTrip(reason: reason.isEmpty ? 'dibatalkan driver' : reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Batalkan Trip'),
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

  // Floating info card anchored below the transparent AppBar, over the
  // fullscreen map -- mirrors user-web-temp/index.html's .top-card overlay.
  // Collapsible (tap the header) so pure-info content like the trip status
  // banner doesn't crowd the map out by default.
  Widget _floatingTopCard(BuildContext context, List<Widget> rows, {Widget? collapsedSummary}) => Positioned(
    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
    left: 16,
    right: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: () => setState(() => _topCardExpanded = !_topCardExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: !_topCardExpanded && collapsedSummary != null
                        ? collapsedSummary
                        : const Text('Detail Perjalanan',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.6)),
                  ),
                  Icon(_topCardExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          if (_topCardExpanded) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...rows,
            const SizedBox(height: 4),
          ],
        ],
      ),
    ),
  );

  // Floating action sheet anchored to the bottom of the screen, over the
  // fullscreen map -- mirrors user-web-temp/index.html's .sheet, scrollable
  // so it never overflows even with the bid input expanded on a short phone.
  // Collapsible via the drag-handle-style header (defaults to expanded so
  // actionable buttons stay reachable without an extra tap).
  Widget _floatingBottomSheet(BuildContext context, List<Widget> children) => Positioned(
    left: 16,
    right: 16,
    bottom: MediaQuery.paddingOf(context).bottom + 16,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.shadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                onTap: () => setState(() => _bottomSheetExpanded = !_bottomSheetExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.surfaceBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
              if (_bottomSheetExpanded) ...[
                const SizedBox(height: 4),
                ...children,
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  // Small circular floating button used for the AppBar's leading/action
  // icons when the AppBar itself is transparent over the fullscreen map.
  Widget _floatingAppBarIcon(IconData icon, VoidCallback onPressed, {String? tooltip}) => Padding(
    padding: const EdgeInsets.all(8),
    child: Material(
      color: AppTheme.surface.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppTheme.textPrimary),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    ),
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

// Trip map with a live driver marker, a route line re-fetched from OSRM as
// the driver moves, and a "center on me" button -- mirrors the same
// live-reroute approach already built into the temp customer web app
// (see user-web-temp/index.html's maybeRerouteLive/drawRoute).
class _LiveTripMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  // Trip status, used to decide the re-route target: pickup before
  // in_progress, destination at/after. Null (e.g. an incoming offer, not yet
  // accepted) is treated the same as pre-in_progress.
  final String? status;

  const _LiveTripMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.status,
  });

  @override
  State<_LiveTripMap> createState() => _LiveTripMapState();
}

class _LiveTripMapState extends State<_LiveTripMap> {
  static const _minRerouteInterval = Duration(seconds: 20);

  // Same CartoDB light/dark tile pair as the temp customer web app
  // (user-web-temp/index.html), toggled via a floating button and
  // persisted so the choice survives app restarts.
  static const _tileUrls = {
    'light': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    'dark': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  };

  final _mapController = MapController();
  LocationService? _locationService;
  LocalStorage? _storage;
  List<LatLng>? _routePoints;
  DateTime? _lastRerouteAt;
  String _mapTheme = 'light';

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _locationService = app.locationService;
    _storage = app.localStorage;
    _mapTheme = _storage!.getMapTheme();
    _locationService!.positionNotifier.addListener(_onPosition);
    final pos = _locationService!.positionNotifier.value;
    if (pos != null) _maybeReroute(pos);
  }

  void _toggleTheme() {
    final next = _mapTheme == 'dark' ? 'light' : 'dark';
    setState(() => _mapTheme = next);
    _storage?.saveMapTheme(next);
  }

  @override
  void didUpdateWidget(covariant _LiveTripMap old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) {
      // Target switched (e.g. accepted -> in_progress): reroute immediately
      // instead of waiting out the throttle window.
      _lastRerouteAt = null;
      final pos = _locationService?.positionNotifier.value;
      if (pos != null) _maybeReroute(pos);
    }
  }

  @override
  void dispose() {
    _locationService?.positionNotifier.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    final pos = _locationService?.positionNotifier.value;
    if (pos != null) _maybeReroute(pos);
  }

  LatLng get _target => widget.status == 'in_progress'
      ? LatLng(widget.destLat, widget.destLng)
      : LatLng(widget.pickupLat, widget.pickupLng);

  Future<void> _maybeReroute(Position pos) async {
    final now = DateTime.now();
    if (_lastRerouteAt != null && now.difference(_lastRerouteAt!) < _minRerouteInterval) return;
    _lastRerouteAt = now;

    final target = _target;
    List<LatLng> points;
    try {
      final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${pos.longitude},${pos.latitude};${target.longitude},${target.latitude}'
          '?overview=full&geometries=geojson');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) throw Exception('osrm ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('no route');
      final coords = (routes[0]['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      points = coords;
    } catch (_) {
      // OSRM unreachable/no route: fall back to a straight line so the
      // driver still sees where they're headed.
      points = [LatLng(pos.latitude, pos.longitude), target];
    }
    if (!mounted) return;
    setState(() => _routePoints = points);
  }

  void _recenter(Position? pos) {
    if (pos == null) return;
    final zoom = _mapController.camera.zoom;
    _mapController.move(LatLng(pos.latitude, pos.longitude), zoom < 15 ? 16 : zoom);
  }

  Widget _mapFab({required IconData icon, required Color color, VoidCallback? onTap}) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 3,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: color),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final dropoff = LatLng(widget.destLat, widget.destLng);
    final center = LatLng((widget.pickupLat + widget.destLat) / 2, (widget.pickupLng + widget.destLng) / 2);

    return Stack(
      children: [
        ValueListenableBuilder<Position?>(
          valueListenable: _locationService!.positionNotifier,
          builder: (context, pos, _) => FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(urlTemplate: _tileUrls[_mapTheme]!, userAgentPackageName: 'com.studex.driver_app'),
              if (_routePoints != null)
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints!, strokeWidth: 4, color: AppTheme.accent),
                ]),
              MarkerLayer(markers: [
                Marker(point: pickup, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 36)),
                Marker(point: dropoff, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
                if (pos != null)
                  Marker(
                    point: LatLng(pos.latitude, pos.longitude),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.two_wheeler, color: AppTheme.accent, size: 32),
                  ),
              ]),
            ],
          ),
        ),
        // Map controls sit vertically centered on the right edge -- clear of
        // both the floating top card and bottom sheet regardless of their
        // collapsed/expanded state, unlike a fixed bottom-corner position.
        Positioned(
          top: 0,
          bottom: 0,
          right: 10,
          child: Align(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapFab(
                  icon: _mapTheme == 'dark' ? Icons.light_mode : Icons.dark_mode,
                  color: AppTheme.accent,
                  onTap: _toggleTheme,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<Position?>(
                  valueListenable: _locationService!.positionNotifier,
                  builder: (context, pos, _) => _mapFab(
                    icon: Icons.my_location,
                    color: pos == null ? AppTheme.textMuted : AppTheme.accent,
                    onTap: pos == null ? null : () => _recenter(pos),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
