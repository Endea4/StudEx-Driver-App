import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().fetchProfile();
    });
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
      app.wsClient.disconnect();
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
      app.wsClient.connect();
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
                  Text(driver.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      onSelected: (_) => _toggleStatus(status),
    );
  }

  Widget _buildGpsCard() {
    return Card(
      child: SwitchListTile(
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
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  @override
  void dispose() {
    final app = context.read<AppProvider>();
    app.locationService.stopStreaming();
    app.wsClient.disconnect();
    super.dispose();
  }
}
