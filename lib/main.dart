import 'package:flutter/material.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FacePresensiApp());
}

class FacePresensiApp extends StatelessWidget {
  const FacePresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISION UNEJ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E1E1E)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Helvetica',
      ),
      home: const SplashScreen(),
    );
  }
}
