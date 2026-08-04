import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/status.dart';
import '../../providers/app_provider.dart';

/// Full-screen pickup/destination map for a single trip-history entry --
/// replaces the old text-only modal dialog with the same fullscreen-map +
/// floating-card layout used for an active trip, minus anything live
/// (no driver marker/re-routing/recenter -- the trip is already over, so
/// there's nothing to track).
class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  static const _tileUrls = {
    'light': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    'dark': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  };

  String _mapTheme = 'light';
  List<LatLng>? _routePoints;

  late final double _pickupLat = (widget.trip['pickup_lat'] ?? 0).toDouble();
  late final double _pickupLng = (widget.trip['pickup_lng'] ?? 0).toDouble();
  late final double _destLat = (widget.trip['dest_lat'] ?? 0).toDouble();
  late final double _destLng = (widget.trip['dest_lng'] ?? 0).toDouble();

  @override
  void initState() {
    super.initState();
    _mapTheme = context.read<AppProvider>().localStorage.getMapTheme();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final pickup = LatLng(_pickupLat, _pickupLng);
    final dest = LatLng(_destLat, _destLng);
    List<LatLng> points;
    try {
      final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '$_pickupLng,$_pickupLat;$_destLng,$_destLat'
          '?overview=full&geometries=geojson');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) throw Exception('osrm ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('no route');
      points = (routes[0]['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      points = [pickup, dest];
    }
    if (!mounted) return;
    setState(() => _routePoints = points);
  }

  Widget _floatingIcon(IconData icon, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.all(8),
    child: Material(
      color: AppTheme.surface.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppTheme.textPrimary),
        onPressed: onPressed,
      ),
    ),
  );

  Widget _floatingCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: AppTheme.surface.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      boxShadow: AppTheme.shadowMd,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    ),
  );

  Widget _badgeRow(String label, Widget badge) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)), badge],
    ),
  );

  Widget _addrRow(String label, double lat, double lng) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))),
        Expanded(child: AddressText(lat, lng, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final status = (trip['status'] ?? '').toString();
    final price = (trip['final_price'] ?? 0).toInt();
    final bid = (trip['current_bid_price'] ?? 0).toInt();
    final paymentStatus = (trip['payment_status'] ?? '').toString();
    final ts = trip['updated_at'] ?? trip['created_at'] ?? '';
    final tsShort = formatDateTime(ts);
    final pickup = LatLng(_pickupLat, _pickupLng);
    final dest = LatLng(_destLat, _destLng);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: _floatingIcon(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(pickup, dest),
                  padding: const EdgeInsets.fromLTRB(60, 160, 60, 240),
                ),
              ),
              children: [
                TileLayer(urlTemplate: _tileUrls[_mapTheme]!, userAgentPackageName: 'com.studex.driver_app'),
                if (_routePoints != null)
                  PolylineLayer(polylines: [
                    Polyline(points: _routePoints!, strokeWidth: 4, color: AppTheme.accent),
                  ]),
                MarkerLayer(markers: [
                  Marker(point: pickup, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 36)),
                  Marker(point: dest, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
                ]),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
            left: 16,
            right: 16,
            child: _floatingCard(children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_statusLabel(status), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _statusColor(status))),
                  const Spacer(),
                  Text(shortCode(trip['order_id']), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ]),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: _floatingCard(children: [
              _badgeRow('Status', StatusBadge.trip(status, small: true)),
              if (paymentStatus.isNotEmpty) _badgeRow('Pembayaran', StatusBadge.payment(paymentStatus, small: true)),
              _row('Harga', 'Rp ${formatMoney(price)}'),
              if (bid > 0) _row('Bid', 'Rp ${formatMoney(bid)}'),
              _addrRow('Jemput', _pickupLat, _pickupLng),
              _addrRow('Tujuan', _destLat, _destLng),
              if (tsShort.isNotEmpty) _row('Waktu', tsShort),
            ]),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_acceptance':
      case 'bargaining':
        return AppTheme.warning;
      case 'accepted':
      case 'in_progress':
      case 'deal':
        return AppTheme.accent;
      case 'completed':
        return AppTheme.success;
      case 'rejected':
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_acceptance':
        return 'Menunggu';
      case 'bargaining':
        return 'Negosiasi';
      case 'accepted':
        return 'Diterima';
      case 'in_progress':
        return 'Berjalan';
      case 'deal':
        return 'Deal';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Batal';
      default:
        return status;
    }
  }
}
