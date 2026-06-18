import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/format.dart';
import '../../providers/app_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/history_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _gpsEnabled = false;
  String _timeFilter = 'today';
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenWsEvents();
      _initAsync();
    });
  }

  Future<void> _initAsync() async {
    await context.read<DriverProvider>().fetchProfile();
    if (!mounted) return;
    context.read<HistoryProvider>().fetchOrders();
    _restoreGps();
  }

  Future<void> _restoreGps() async {
    final app = context.read<AppProvider>();
    final driver = context.read<DriverProvider>().driver;
    final isReady = (driver?.status ?? '').toLowerCase() == 'ready';
    final wasEnabled = app.localStorage.getGpsEnabled();
    if (wasEnabled || isReady) {
      final hasPermission = await app.locationService.checkPermissions();
      if (hasPermission) {
        app.locationService.startStreaming();
        app.locationService.setGpsStatus(true);
        app.localStorage.saveGpsEnabled(true);
        setState(() => _gpsEnabled = true);
      }
    }
  }

  void _listenWsEvents() {
    final app = context.read<AppProvider>();
    _wsSubscription = app.wsClient.stream.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String? ?? '';
      if (type == 'match.completed') {
        _showNotification('Pesanan Baru!', 'Ada pesanan masuk', Icons.local_shipping, AppTheme.brandCyan);
      } else if (type == 'trip.created') {
        _showNotification('Trip Dibuat', 'Trip menunggu konfirmasi', Icons.assignment, AppTheme.warning);
      } else if (type == 'trip.started') {
        _showNotification('Trip Dimulai', 'Perjalanan dimulai', Icons.directions_bike, AppTheme.success);
      } else if (type == 'trip.completed') {
        _showNotification('Trip Selesai', 'Perjalanan selesai', Icons.check_circle, AppTheme.success);
      } else if (type == 'trip.cancelled') {
        _showNotification('Trip Dibatalkan', 'Perjalanan dibatalkan', Icons.cancel, AppTheme.danger);
      } else if (type == 'match.timeout') {
        _showNotification('Match Timeout', 'Tidak ada driver tersedia', Icons.timer_off, AppTheme.textMuted);
      }
    });
  }

  void _showNotification(String title, String body, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                  Text(body, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.surfaceBorder),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleStatus(String status) async {
    if (status == 'ready' && !_gpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nyalakan GPS terlebih dahulu sebelum Ready'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    await context.read<DriverProvider>().updateStatus(status);
    if (status == 'offline' && _gpsEnabled) {
      _toggleGps();
    }
  }

  Future<void> _toggleGps() async {
    final app = context.read<AppProvider>();
    final locationService = app.locationService;

    if (_gpsEnabled) {
      locationService.stopStreaming();
      locationService.setGpsStatus(false);
      app.localStorage.saveGpsEnabled(false);
      setState(() => _gpsEnabled = false);
      await context.read<DriverProvider>().updateStatus('offline');
    } else {
      final hasPermission = await locationService.checkPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')),
          );
        }
        return;
      }
      locationService.startStreaming();
      locationService.setGpsStatus(true);
      app.localStorage.saveGpsEnabled(true);
      setState(() => _gpsEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('StudEx', style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            )),
            const SizedBox(width: 4),
            Text('Driver', style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: AppTheme.accent,
              letterSpacing: -0.3,
            )),
          ],
        ),
        actions: [
          Semantics(
            label: 'logout_button',
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 22),
              onPressed: () async {
                await context.read<AppProvider>().logout();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/sign-in');
              },
            ),
          ),
        ],
      ),
      body: Consumer<DriverProvider>(
        builder: (context, driverProvider, _) {
          final driver = driverProvider.driver;

          if (driverProvider.isLoading && driver == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }

          if (driver == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                  const SizedBox(height: 16),
                  const Text('Gagal memuat profil', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => driverProvider.fetchProfile(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.accent,
            onRefresh: () => driverProvider.fetchProfile(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                _buildProfileHero(driver),
                const SizedBox(height: 20),
                _buildStatusSection(driver),
                const SizedBox(height: 16),
                _buildGpsCard(),
                const SizedBox(height: 24),
                _buildStatsRow(driver, driverProvider),
                const SizedBox(height: 28),
                const SectionHeader(title: 'Menu'),
                _buildNavigationList(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHero(dynamic driver) {
    final hasPhoto = driver.profilePhoto?.isNotEmpty == true;
    return Semantics(
      label: 'profile_card',
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brandCyan, AppTheme.brandCyanDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(driver.profilePhoto, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(
                        driver.displayName?.isNotEmpty == true
                            ? driver.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandNavy,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: 'driver_name',
                    child: Text(
                      driver.displayName ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (driver.phone?.isNotEmpty == true)
                    Text(
                      driver.phone,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  const SizedBox(height: 4),
                  if (driver.gender?.isNotEmpty == true)
                    Row(
                      children: [
                        Icon(driver.gender.toLowerCase() == 'male' ? Icons.male : Icons.female,
                            size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(driver.gender, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  const SizedBox(height: 6),
                  if (driver.vehicleType?.isNotEmpty == true || driver.plateNumber?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.motorcycle, size: 14, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Text(
                            '${driver.vehicleType ?? ''} ${driver.plateNumber ?? ''}'.trim(),
                            style: const TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Edit profile button
            Semantics(
              label: 'edit_profile',
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textMuted),
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(dynamic driver) {
    final status = (driver.status ?? 'offline').toLowerCase();
    final isReady = status == 'ready';
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
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isReady ? AppTheme.success : AppTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isReady ? 'Siap Menerima Pesanan' : 'Offline',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isReady ? AppTheme.success : AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statusChip('Ready', 'ready', status, AppTheme.success)),
              const SizedBox(width: 12),
              Expanded(child: _statusChip('Offline', 'offline', status, AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value, String current, Color color) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => _toggleStatus(value),
      child: Semantics(
        label: 'status_$value',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.4) : AppTheme.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsCard() {
    return Semantics(
      label: 'gps_card',
      child: GestureDetector(
        onTap: _toggleGps,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gpsEnabled ? AppTheme.accent.withOpacity(0.08) : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _gpsEnabled ? AppTheme.accent.withOpacity(0.3) : AppTheme.surfaceBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _gpsEnabled ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _gpsEnabled ? Icons.gps_fixed : Icons.gps_off,
                  color: _gpsEnabled ? AppTheme.accent : AppTheme.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gpsEnabled ? 'GPS Aktif' : 'GPS Nonaktif',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _gpsEnabled ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _gpsEnabled ? 'Lokasi dibagikan ke sistem' : 'Aktifkan untuk menerima pesanan',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('gps_toggle'),
                value: _gpsEnabled,
                onChanged: (_) => _toggleGps(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // One-line stats with time filter
  Widget _buildStatsRow(dynamic driver, DriverProvider driverProvider) {
    final historyProvider = context.watch<HistoryProvider>();
    final now = DateTime.now();
    final cutoff = _timeFilter == 'today'
        ? DateTime(now.year, now.month, now.day)
        : _timeFilter == 'week'
            ? now.subtract(Duration(days: now.weekday - 1))
            : DateTime(now.year, now.month, 1);

    final filtered = historyProvider.orders
        .where((o) => o.createdAt.isAfter(cutoff) && o.status == 'completed')
        .toList();
    final income = filtered.fold<int>(0, (sum, o) => sum + o.finalPrice);
    final orderCount = filtered.length;
    final rating = driverProvider.reputationScore;

    return Column(
      children: [
        Row(
          children: [
            _filterChip('Hari ini', 'today'),
            const SizedBox(width: 8),
            _filterChip('Minggu ini', 'week'),
            const SizedBox(width: 8),
            _filterChip('Bulan ini', 'month'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pendapatan', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('Rp ${formatMoney(income)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.brandCyan, letterSpacing: -0.5)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.surfaceBorder),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Pesanan', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('$orderCount',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.surfaceBorder),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Rating', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.warning, letterSpacing: -0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accent.withOpacity(0.4) : AppTheme.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.accent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList() {
    return Column(
      children: [
        _navTile(Icons.history_rounded, 'Riwayat Pesanan', '/history', AppTheme.brandCyan),
        const SizedBox(height: 8),
        _navTile(Icons.money_off_rounded, 'Daftar Utang', '/debts', AppTheme.danger),
        const SizedBox(height: 8),
        _navTile(Icons.star_rate_rounded, 'Rating Menunggu', '/ratings', AppTheme.warning),
        const SizedBox(height: 8),
        _navTile(Icons.assessment_rounded, 'Reputasi', '/reputation', AppTheme.success),
      ],
    );
  }

  Widget _navTile(IconData icon, String title, String route, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: ListTile(
        key: Key('nav_$route'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Semantics(
          label: 'nav_$title',
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
