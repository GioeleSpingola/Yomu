import 'package:flutter/material.dart';

// I nostri megafoni globali per le impostazioni in tempo reale!
final ValueNotifier<Color> appColorNotifier = ValueNotifier(const Color(0xFFCA98FF));
final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<bool> appBlackNotifier = ValueNotifier(true);
final ValueNotifier<Locale> appLanguageNotifier = ValueNotifier(const Locale('it'));

final ValueNotifier<bool> appSystemFontNotifier = ValueNotifier(false);
final ValueNotifier<double> appTextScaleNotifier = ValueNotifier(1.0);


class YomuColors {
  // NIENTE PIÙ "const" QUI! Ora i colori sono dinamici.
  static Color primary = const Color(0xFFCA98FF);
  static Color onPrimary = const Color(0xFF380092);
  static Color secondary = const Color(0xFFD0BCFF); // <-- Aggiunto!
  
  static Color surface = const Color(0xFF121212);
  static Color onSurface = const Color(0xFFE6E1E5);
  static Color onSurfaceVariant = const Color(0xFFCAC4D0);
  
  static Color surfaceContainer = const Color(0xFF1E1E1E); // <-- Aggiunto!
  static Color surfaceContainerHigh = const Color(0xFF2B2930);
  static Color surfaceContainerHighest = const Color(0xFF36343B);
  
  static Color outline = const Color(0xFF938F99);
  static Color outlineVariant = const Color(0xFF49454F);
  
  static Color error = const Color(0xFFFFB4AB);

  static Color get tertiary => const Color(0xFFFFCA28);
  static Color get onTertiary => const Color(0xFF251A00);
}