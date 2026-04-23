import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import 'auth_screen.dart';
import '../yomu_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // 1. Diamo comunque 2 secondi di pausa per far vedere il logo e far
    // inizializzare tutto correttamente sotto il cofano.
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // 2. Chiediamo a Supabase se ha trovato una sessione valida in memoria
    final session = Supabase.instance.client.auth.currentSession;

    // 3. Smistamento intelligente
    if (session != null) {
      // C'è una sessione: vai all'app principale
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      // Nessuna sessione: vai subito al login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo scuro
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_stories,
              size: 80,
              color: Colors.deepPurpleAccent,
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
            const CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ],
        ),
      ),
    );
  }
}
