import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/driver_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentController.text.trim();
    final newPw = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      _showError('Semua field harus diisi');
      return;
    }
    if (newPw.length < 4) {
      _showError('Password baru minimal 4 karakter');
      return;
    }
    if (newPw != confirm) {
      _showError('Konfirmasi password tidak cocok');
      return;
    }

    setState(() => _isSaving = true);
    final ok = await context.read<DriverProvider>().changePassword(newPw);
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password berhasil diubah'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      } else {
        _showError(context.read<DriverProvider>().error ?? 'Gagal mengubah password');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Ubah Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: AppTheme.space4),
                const Expanded(
                  child: Text(
                    'Gunakan password yang mudah kamu ingat namun sulit ditebak orang lain.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildField('Password Saat Ini', _currentController, Icons.lock_outline, obscure: _obscureCurrent,
                suffix: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted, size: 20),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                )),
            const SizedBox(height: 20),
            _buildField('Password Baru', _newController, Icons.lock, obscure: _obscureNew,
                suffix: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted, size: 20),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                )),
            const SizedBox(height: 20),
            _buildField('Konfirmasi Password Baru', _confirmController, Icons.lock, obscure: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted, size: 20),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                )),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _changePassword,
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Ubah Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.cardDecoration(radius: AppTheme.radiusMd),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
              suffixIcon: suffix,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
