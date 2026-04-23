import 'package:flutter/material.dart';

final ValueNotifier<Color> yomuPrimaryColor = ValueNotifier<Color>(
  const Color(0xFFCA98FF),
);

class YomuColors {
  // Colori statici (non cambiano mai)
  static const surface = Color(0xFF0E0E0E);
  static const surfaceContainer = Color(0xFF1A1A1A);
  static const surfaceContainerHigh = Color(0xFF20201F);
  static const surfaceContainerHighest = Color(0xFF262626);
  static const onSurface = Color(0xFFFFFFFF);
  static const onSurfaceVariant = Color(0xFFADAAAA);

  static const onPrimary = Color(0xFF46007D);
  static const secondary = Color(0xFF00FBFB);
  static const outline = Color(0xFF767575);
  static const outlineVariant = Color(0xFF484847);
  static const error = Color(0xFFFF6E84);

  static Color get primary => yomuPrimaryColor.value;
}
