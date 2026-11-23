import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_palette.dart';
import 'enroll_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Menu utama setelah splash, ditampilkan sebagai kartu bergaya "Quick Access":
/// satu baris tiga kartu di tablet landscape. Lebar sempit memakai daftar kartu
/// sebagai cadangan. Kartu "Enroll Wajah Baru" membuka [EnrollScreen].
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const _green = Color(0xFF2FA23A);
  static const _greenDark = Color(0xFF1F7F2B);
  static const _violet = Color(0xFF7C3AED);
  static const _blue = Color(0xFF2563EB);

  // Di atas lebar ini tiga kartu muat dalam satu baris.
  static const _wideBreakpoint = 640.0;

  /// Dialog NIP/NRP/NIK dulu, baru layar kamera depan.
  Future<void> _openEnroll(BuildContext context) async {
    final nip = await showEnrollNipDialog(context);
    if (nip == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EnrollScreen(nip: nip)),
    );
  }

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

    final items = [
      _MenuItem(
        icon: Icons.person_add_alt_1,
        title: 'Enroll Wajah Baru',
        subtitle: 'Rekam data wajah baru',
        accent: _blue,
        onPressed: () => _openEnroll(context),
      ),
      _MenuItem(
        icon: Icons.face_retouching_natural,
        title: 'Vision',
        subtitle: 'Pengenalan wajah',
        accent: _green,
        onPressed: () => _openRecognition(context),
      ),
      _MenuItem(
        icon: Icons.settings_outlined,
        title: 'Pengaturan',
        subtitle: 'Mode tema',
        accent: _violet,
        onPressed: () => _openSettings(context),
      ),
    ];

    return Scaffold(
      backgroundColor: p.pageBackground,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat datang',
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih layanan yang ingin dibuka.',
                        style: TextStyle(color: p.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      _sectionTitle(p, 'Menu Utama'),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= _wideBreakpoint) {
                            // Tinggi kartu tetap, supaya isi tidak terpotong saat
                            // lebar layar berubah.
                            return GridView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 190,
                                  ),
                              children: [
                                for (final item in items)
                                  _MenuTile(item: item, wide: true),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final item in items) ...[
                                _MenuTile(item: item, wide: false),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppPalette p, String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: p.ink,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Header gradien hijau UPATIK, sama dengan layar pengenalan.
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_greenDark, _green]),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Image.asset(
              AppConfig.logoAsset,
              width: 46,
              height: 46,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.school, color: Colors.amber, size: 42),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VISION UNEJ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Visual Identification & Smart Integrated Online Network',
                    style: TextStyle(color: Color(0xFFE5F5E7), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'UPATIK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data satu kartu menu. `onPressed` `null` berarti kartu nonaktif.
class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onPressed;
}

/// Kartu berlatar warna lembut dengan ikon bulat berwarna penuh. Mode `wide`
/// menaruh ikon di atas dan judul di bawah; mode sempit memakai baris mendatar.
class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.wide});

  static const _disabledColor = Color(0xFF9CA3AF);

  final _MenuItem item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = item.onPressed != null;
    final accent = enabled ? item.accent : _disabledColor;

    final icon = Container(
      width: wide ? 56 : 52,
      height: wide ? 56 : 52,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      child: Icon(item.icon, color: Colors.white, size: 26),
    );

    final titleStyle = TextStyle(
      color: p.ink,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
    final subtitleStyle = TextStyle(color: p.muted, fontSize: 13);

    final content = wide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const Spacer(),
              Text(item.title, style: titleStyle),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: Text(item.subtitle, style: subtitleStyle)),
                  if (enabled) Icon(Icons.chevron_right, color: accent),
                ],
              ),
            ],
          )
        : Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: titleStyle),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              if (enabled) Icon(Icons.chevron_right, color: accent),
            ],
          );

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.onPressed,
          child: Padding(
            padding: EdgeInsets.all(wide ? 18 : 16),
            child: content,
          ),
        ),
      ),
    );
  }
}
