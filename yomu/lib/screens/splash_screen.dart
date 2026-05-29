import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'main_screen.dart';
import '../yomu_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    setState(() => _authFailed = false);
    // Diamo 2 secondi di pausa per far vedere il logo
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool useAppLock = prefs.getBool('useAppLock') ?? false;

    if (useAppLock) {
      final LocalAuthentication auth = LocalAuthentication();
      try {
        final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
        final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

        if (canAuthenticate) {
          final bool didAuthenticate = await auth.authenticate(
            localizedReason: 'Sblocca Yomu per accedere alla tua libreria',
          );

          if (!didAuthenticate) {
            // L'utente ha annullato l'impronta
            if (mounted) setState(() => _authFailed = true);
            return;
          }
        }
      } on PlatformException catch (e) {
        debugPrint('Errore biometria: $e');
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YomuColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 80,
              color: YomuColors.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'YOMU',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manga Reader',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 50),
            if (_authFailed)
              FilledButton.icon(
                onPressed: _checkAuthAndNavigate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text(
                  'Riprova a sbloccare',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: YomuColors.primary,
                  foregroundColor: YomuColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              CircularProgressIndicator(color: YomuColors.primary),
          ],
        ),
      ),
    );
  }
}