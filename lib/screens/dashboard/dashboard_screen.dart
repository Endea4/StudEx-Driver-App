import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/driver_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _gpsEnabled = false;
  bool _showReasonDialog = false;
  String _pendingStatus = '';
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().fetchProfile();
      _listenWsEvents();
    });
  }

  void _listenWsEvents() {
    final app = context.read<AppProvider>();
    _wsSubscription = app.wsClient.stream.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String? ?? '';
      if (type == 'match.completed') {
        final data = event['data'] as Map<String, dynamic>? ?? {};
        final orderId = data['order_id'] ?? '-';
        final score = data['score'] ?? 0;
        _showNotification(
          'Pesanan Baru!',
          'Order $orderId masuk (score: ${score.toStringAsFixed(2)})',
          Icons.local_shipping,
          Colors.blue,
        );
      } else if (type == 'trip.created') {
        final data = event['data'] as Map<String, dynamic>? ?? {};
        final tripId = data['trip_id'] ?? '-';
        _showNotification(
          'Trip Dibuat',
          'Trip $tripId menunggu konfirmasi',
          Icons.assignment,
          Colors.orange,
        );
      } else if (type == 'trip.started') {
        _showNotification(
          'Trip Dimulai',
          'Perjalanan dimulai',
          Icons.directions_bike,
          Colors.green,
        );
      } else if (type == 'trip.completed') {
        _showNotification(
          'Trip Selesai',
          'Perjalanan selesai',
          Icons.check_circle,
          Colors.teal,
        );
      } else if (type == 'trip.cancelled') {
        _showNotification(
          'Trip Dibatalkan',
          'Perjalanan dibatalkan',
          Icons.cancel,
          Colors.red,
        );
      } else if (type == 'match.timeout') {
        _showNotification(
          'Match Timeout',
          'Tidak ada driver tersedia',
          Icons.timer_off,
          Colors.grey,
        );
      }
    });
  }

  void _showNotification(String title, String body, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(body, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color.withOpacity(0.9),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _toggleStatus(String status) async {
    if (status == 'izin' || status == 'cuti') {
      _pendingStatus = status;
      _showReasonDialog = true;
      return;
    }

    await context.read<DriverProvider>().updateStatus(status);
  }

  Future<void> _submitStatusWithReason(String reason) async {
    Navigator.pop(context);
    await context.read<DriverProvider>().updateStatus(_pendingStatus, reason: reason);
  }

  Future<void> _toggleGps() async {
    final app = context.read<AppProvider>();
    final locationService = app.locationService;

    if (_gpsEnabled) {
      locationService.stopStreaming();
      setState(() => _gpsEnabled = false);
    } else {
      final hasPermission = await locationService.checkPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')));
        }
        return;
      }
      locationService.startStreaming();
      setState(() => _gpsEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppProvider>().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/sign-in');
              }
            },
          ),
        ],
      ),
      body: Consumer<DriverProvider>(
        builder: (context, driverProvider, _) {
          final driver = driverProvider.driver;

          if (driverProvider.isLoading && driver == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (driver == null) {
            return const Center(child: Text('Gagal memuat profil'));
          }

          return RefreshIndicator(
            onRefresh: () => driverProvider.fetchProfile(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileCard(driver),
                const SizedBox(height: 16),
                _buildStatusCard(driver),
                const SizedBox(height: 16),
                _buildGpsCard(),
                const SizedBox(height: 16),
                _buildStatsCard(driver),
                const SizedBox(height: 16),
                _buildNavigationCards(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(dynamic driver) {
    final hasPhoto = driver.profilePhoto.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: hasPhoto ? NetworkImage(driver.profilePhoto) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      driver.displayName.isNotEmpty ? driver.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(label: 'driver_name', child: Text(driver.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 4),
                  Text(driver.vehicleType, style: const TextStyle(color: Colors.grey)),
                  Text(driver.plateNumber, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(dynamic driver) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${driver.status.toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip('Ready', 'ready', driver.status, Colors.green),
                _statusChip('Offline', 'offline', driver.status, Colors.grey),
                _statusChip('Izin', 'izin', driver.status, Colors.orange),
                _statusChip('Cuti', 'cuti', driver.status, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String status, String currentStatus, Color color) {
    final isSelected = currentStatus == status;
    return ChoiceChip(
      key: Key('status_$status'),
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      onSelected: (_) => _toggleStatus(status),
    );
  }

  Widget _buildGpsCard() {
    return Card(
      child: SwitchListTile(
        key: const Key('gps_toggle'),
        title: const Text('Bagikan Lokasi GPS'),
        subtitle: Text(_gpsEnabled ? 'GPS aktif - lokasi dibagikan' : 'GPS nonaktif'),
        secondary: Icon(
          _gpsEnabled ? Icons.gps_fixed : Icons.gps_off,
          color: _gpsEnabled ? Colors.green : Colors.grey,
        ),
        value: _gpsEnabled,
        onChanged: (_) => _toggleGps(),
      ),
    );
  }

  Widget _buildStatsCard(dynamic driver) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Pesanan', '${driver.totalOrders}'),
                _statItem('Rating', '${driver.reputationScore.toStringAsFixed(1)}'),
                _statItem('Pendapatan', 'Rp ${driver.totalIncome}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildNavigationCards() {
    return Column(
      children: [
        _navCard(Icons.history, 'Riwayat Pesanan', '/history'),
        _navCard(Icons.money_off, 'Daftar Utang', '/debts'),
        _navCard(Icons.star_rate, 'Rating Menunggu', '/ratings'),
        _navCard(Icons.assessment, 'Reputasi', '/reputation'),
      ],
    );
  }

  Widget _navCard(IconData icon, String title, String route) {
    return Card(
      child: ListTile(
        key: Key('nav_$route'),
        leading: Icon(icon),
        title: Semantics(label: 'nav_$title', child: Text(title)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    final app = context.read<AppProvider>();
    app.locationService.stopStreaming();
    app.wsClient.disconnect();
    super.dispose();
  }
}
