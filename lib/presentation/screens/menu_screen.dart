import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Menu utama setelah splash: "Enroll Wajah Baru", "Vision", dan "Pengaturan".
/// Kedua menu pertama saat ini mengarah ke layar pengenalan wajah ([HomeScreen]);
/// alur enroll akan dibahas dan diisi kemudian.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const _green = Color(0xFF2FA23A);
  static const _greenDark = Color(0xFF1F7F2B);

  void _openRecognition(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VISION UNEJ',
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih menu',
                    style: TextStyle(color: p.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  _menuButton(
                    context,
                    icon: Icons.person_add_alt_1,
                    title: 'Enroll Wajah Baru',
                    subtitle: 'Rekam data wajah baru',
                    onPressed: () => _openRecognition(context),
                  ),
                  const SizedBox(height: 16),
                  _menuButton(
                    context,
                    icon: Icons.face_retouching_natural,
                    title: 'Vision',
                    subtitle: 'Pengenalan wajah',
                    onPressed: () => _openRecognition(context),
                  ),
                  const SizedBox(height: 16),
                  _menuButton(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan',
                    subtitle: 'Mode tema',
                    onPressed: () => _openSettings(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    final p = AppPalette.of(context);

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _greenDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
