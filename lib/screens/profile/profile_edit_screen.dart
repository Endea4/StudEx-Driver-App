import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/driver_provider.dart';
import '../../providers/app_provider.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _displayNameController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _plateController;
  String _selectedGender = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final driver = context.read<DriverProvider>().driver;
    _nameController = TextEditingController(text: driver?.name ?? '');
    _displayNameController = TextEditingController(text: driver?.displayName ?? '');
    _vehicleTypeController = TextEditingController(text: driver?.vehicleType ?? '');
    _plateController = TextEditingController(text: driver?.plateNumber ?? '');
    _selectedGender = driver?.gender ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _vehicleTypeController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final fields = <String, dynamic>{
      'name': _nameController.text.trim(),
      'display_name': _displayNameController.text.trim(),
      'vehicle_type': _vehicleTypeController.text.trim(),
      'plate_number': _plateController.text.trim(),
    };
    if (_selectedGender.isNotEmpty) {
      fields['gender'] = _selectedGender;
    }
    final ok = await context.read<DriverProvider>().updateProfile(fields);
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil berhasil diperbarui'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      } else {
        final error = context.read<DriverProvider>().error ?? 'Gagal menyimpan profil';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>().driver;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar section
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.brandCyan, AppTheme.brandCyanDark],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        driver?.displayName?.isNotEmpty == true
                            ? driver!.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(driver?.phone ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Form fields
            _buildSection('Informasi Dasar'),
            const SizedBox(height: 12),
            _buildField('Nama Lengkap', _nameController, Icons.person_outline),
            const SizedBox(height: 14),
            _buildField('Nama Panggilan', _displayNameController, Icons.badge_outlined),
            const SizedBox(height: 14),
            _buildGenderSelector(),
            const SizedBox(height: 28),
            _buildSection('Kendaraan'),
            const SizedBox(height: 12),
            _buildField('Tipe Kendaraan', _vehicleTypeController, Icons.motorcycle, hint: 'Contoh: Matic, Manual'),
            const SizedBox(height: 14),
            _buildField('Plat Nomor', _plateController, Icons.pin_outlined, hint: 'Contoh: AB 1234 CD'),
            const SizedBox(height: 40),
            // Save button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Simpan Perubahan'),
              ),
            ),
            const SizedBox(height: 16),
            // Change password button
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/change-password'),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Ubah Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.surfaceBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5));
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Row(
          children: [
            _genderChip('Male', 'Male', Icons.male),
            const SizedBox(width: 10),
            _genderChip('Female', 'Female', Icons.female),
          ],
        ),
      ],
    );
  }

  Widget _genderChip(String label, String value, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.12) : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accent.withOpacity(0.4) : AppTheme.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? AppTheme.accent : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.accent : AppTheme.textMuted,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
