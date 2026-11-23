import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/theme_controller.dart';

/// Layar pengaturan. Saat ini hanya berisi mode tema.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBackground,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: p.pageBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) {
          final palette = AppPalette.of(context);
          final mode = ThemeController.instance.mode;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'TAMPILAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Tema',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih tampilan terang, gelap, atau mengikuti pengaturan perangkat.',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto),
                            label: Text('Sistem'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode),
                            label: Text('Terang'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode),
                            label: Text('Gelap'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) =>
                            ThemeController.instance.setMode(selection.first),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
