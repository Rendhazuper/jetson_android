import 'package:flutter/material.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_controller.dart';
import 'presentation/screens/camera_permission_gate.dart';
import 'presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const FacePresensiApp());
}

class FacePresensiApp extends StatelessWidget {
  const FacePresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'VISION UNEJ',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E1E1E)),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Helvetica',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E1E1E),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: AppPalette.dark.pageBackground,
          fontFamily: 'Helvetica',
        ),
        themeMode: ThemeController.instance.mode,
        // Gerbang izin kamera berada di atas Navigator, jadi semua layar terkunci
        // sampai izin kamera diberikan.
        builder: (context, child) =>
            CameraPermissionGate(child: child ?? const SizedBox.shrink()),
        home: const SplashScreen(),
      ),
    );
  }
}
