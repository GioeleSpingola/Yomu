import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsSyncService {
  static final _client = Supabase.instance.client;

  static const _keyMap = {
    'themeMode': 'theme_mode',
    'appLanguage': 'app_language',
    'pureBlack': 'pure_black',
    'themeColorIndex': 'color_index',
    'useSystemFont': 'use_system_font',
    'fontScale': 'font_scale',
    'readingMode': 'reading_mode',
  };

  static Future<void> downloadSettings({
    required ValueNotifier<ThemeMode> themeNotifier,
    required ValueNotifier<Locale> languageNotifier,
    required ValueNotifier<bool> blackNotifier,
    required ValueNotifier<Color> colorNotifier,
    required ValueNotifier<bool> systemFontNotifier,
    required ValueNotifier<double> textScaleNotifier,
    required List<Color> themeColors,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) {
        await uploadAllSettings();
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final theme = row['theme_mode'] as String? ?? 'Scuro';
      await prefs.setString('themeMode', theme);
      if (theme == 'Chiaro') {
        themeNotifier.value = ThemeMode.light;
      } else if (theme == 'Predefinito di sistema') {
        themeNotifier.value = ThemeMode.system;
      } else {
        themeNotifier.value = ThemeMode.dark;
      }

      final lang = row['app_language'] as String? ?? 'Italiano';
      await prefs.setString('appLanguage', lang);
      languageNotifier.value = Locale(lang == 'Italiano' ? 'it' : 'en');

      final pureBlack = row['pure_black'] as bool? ?? true;
      await prefs.setBool('pureBlack', pureBlack);
      blackNotifier.value = pureBlack;

      final colorIndex = (row['color_index'] as num?)?.toInt() ?? 0;
      await prefs.setInt('themeColorIndex', colorIndex);
      if (colorIndex >= 0 && colorIndex < themeColors.length) {
        colorNotifier.value = themeColors[colorIndex];
      }

      final sysFont = row['use_system_font'] as bool? ?? false;
      await prefs.setBool('useSystemFont', sysFont);
      systemFontNotifier.value = sysFont;

      final fontScale = row['font_scale'] as String? ?? 'Normale';
      await prefs.setString('fontScale', fontScale);
      double scale = 1.0;
      if (fontScale == 'Piccola') scale = 0.85;
      if (fontScale == 'Grande') scale = 1.15;
      if (fontScale == 'Extra grande') scale = 1.30;
      textScaleNotifier.value = scale;

      final readingMode = row['reading_mode'] as String?;
      if (readingMode != null) {
        await prefs.setString('readingMode', readingMode);
      }
    } catch (e) {
      debugPrint('Errore download settings: $e');
    }
  }

  static Future<void> uploadAllSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await _client.from('user_settings').upsert({
        'user_id': user.id,
        'theme_mode': prefs.getString('themeMode') ?? 'Scuro',
        'app_language': prefs.getString('appLanguage') ?? 'Italiano',
        'pure_black': prefs.getBool('pureBlack') ?? true,
        'color_index': prefs.getInt('themeColorIndex') ?? 0,
        'use_system_font': prefs.getBool('useSystemFont') ?? false,
        'font_scale': prefs.getString('fontScale') ?? 'Normale',
        'reading_mode': prefs.getString('readingMode') ?? 'Destra verso Sinistra',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Errore upload settings: $e');
    }
  }

  static Future<void> syncSetting(String localKey, dynamic value) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final remoteKey = _keyMap[localKey];
    if (remoteKey == null) return;

    try {
      await _client.from('user_settings').upsert({
        'user_id': user.id,
        remoteKey: value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Errore sync setting $localKey: $e');
    }
  }
}
