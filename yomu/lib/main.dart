import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart'; // Fai partire l'app dalla tua schermata di caricamento
import 'yomu_colors.dart';

void main() async {
  // 1. Diciamo a Flutter di preparare i motori prima di fare qualsiasi altra cosa
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Apriamo il collegamento con Supabase. L' "await" è FONDAMENTALE!
  // Aspetta che Supabase sia pronto prima di andare avanti.
  await Supabase.initialize(
    url: 'https://ugpvxhsuxspeglueotvr.supabase.co',
    anonKey: 'sb_publishable_135VW_z4BzrYDsbQS-QVTQ_wYiXnm1_',
  );

  // 3. Solo quando il database è pronto, lanciamo l'interfaccia grafica
  runApp(const YomuApp());
}

class YomuApp extends StatelessWidget {
  const YomuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Il nostro megafono dei colori che ascolta il tema scelto nelle impostazioni!
    return ValueListenableBuilder<Color>(
      valueListenable: yomuPrimaryColor,
      builder: (context, primaryColor, child) {
        return MaterialApp(
          title: 'Yomu',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: YomuColors.surface,
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              surface: YomuColors.surface,
            ),
          ),
          // Partiamo dalla SplashScreen, lei poi smisterà l'utente al MainScreen o al Login
          home: const SplashScreen(),
        );
      },
    );
  }
}
