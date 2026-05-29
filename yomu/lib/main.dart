import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🌟 NUOVO IMPORT
import 'package:flutter/foundation.dart'; // Serve per usare kIsWeb

import 'Lingue/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/settings_sync_service.dart';
import 'yomu_colors.dart';

// 🌟 IL MOTORE IN BACKGROUND CON NOTIFICHE TIPO MIHON!
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    try {
      // 1. Inizializziamo Supabase
      await Supabase.initialize(
        url: 'https://ugpvxhsuxspeglueotvr.supabase.co',
        anonKey: 'sb_publishable_135VW_z4BzrYDsbQS-QVTQ_wYiXnm1_',
      );

      // 2. Inizializziamo il motore delle Notifiche
      const AndroidInitializationSettings initSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: initSettingsAndroid,
      );
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      final prefs =
          await SharedPreferences.getInstance(); // 🌟 FIX 1: Abbiamo definito prefs!
      final user = Supabase.instance.client.auth.currentUser;
      final String? userId = user?.id ?? prefs.getString('cached_user_id');

      if (userId == null)
        return Future.value(
          true,
        ); // 🌟 FIX 2: Ora controlliamo userId, non user!

      final libraryData = await Supabase.instance.client
          .from('libreria')
          .select('id, manga_id, title, capitoli_totali')
          .eq(
            'user_id',
            userId,
          ); // 🌟 FIX 3: Ora Dart sa che userId non è nullo.

      if (libraryData.isEmpty) return Future.value(true);

      int progress = 0;
      int total = libraryData.length;
      List<String> mangaAggiornati = [];

      for (var item in libraryData) {
        final mangaId = item['manga_id'];
        final titolo = item['title'] ?? 'Manga';
        final vecchiTotali = item['capitoli_totali'] ?? 0;

        // 🌟 3. MOSTRA LA NOTIFICA CON LA BARRA DI PROGRESSO IN TEMPO REALE
        // 🌟 3. MOSTRA LA NOTIFICA CON LA BARRA DI PROGRESSO E IL LOGO!
        final AndroidNotificationDetails progressDetails =
            AndroidNotificationDetails(
              'sync_progress_channel',
              'Aggiornamento Libreria',
              channelDescription:
                  'Mostra il progresso dell\'aggiornamento in background',
              importance: Importance.low,
              priority: Priority.low,
              showProgress: true,
              maxProgress: total,
              progress: progress,
              ongoing: true,
              onlyAlertOnce: true,
              icon: '@mipmap/ic_launcher',
              largeIcon: const DrawableResourceAndroidBitmap(
                '@drawable/ic_notification_large',
              ),
            );

        await flutterLocalNotificationsPlugin.show(
          0, // L'ID 0 è dedicato alla barra di caricamento
          'Aggiornamento libreria in corso...',
          'Controllo: $titolo ($progress/$total)',
          NotificationDetails(android: progressDetails),
        );

        await Future.delayed(
          const Duration(milliseconds: 600),
        ); // Filtro anti-ban di MangaDex (largo perché in background)

        final url = Uri.parse(
          'https://api.mangadex.org/manga/$mangaId/feed?limit=500&translatedLanguage[]=it&translatedLanguage[]=en&order[chapter]=desc',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final list = data['data'] as List;

          final uniqueChapters = <String, dynamic>{};
          for (var ch in list) {
            final ext = ch['attributes']['externalUrl'];
            if (ext != null && ext.toString().isNotEmpty) continue;

            final chNum = ch['attributes']['chapter']?.toString() ?? '';
            final chTitle = ch['attributes']['title']?.toString() ?? '';
            final key = chNum.isNotEmpty ? chNum : chTitle;
            if (key.isNotEmpty) uniqueChapters[key] = ch;
          }

          final nuoviTotali = uniqueChapters.length;

          if (nuoviTotali > vecchiTotali) {
            await Supabase.instance.client
                .from('libreria')
                .update({'capitoli_totali': nuoviTotali, 'is_new': true})
                .eq('id', item['id']);

            // Salviamo il nome del manga per scriverlo nella notifica finale!
            mangaAggiornati.add(titolo);
          }
        }

        progress++;
      }

      // 🌟 4. FINITO! CANCELLA LA BARRA DI CARICAMENTO
      await flutterLocalNotificationsPlugin.cancel(0);

      // 🌟 5. MOSTRA LA NOTIFICA FINALE COL RIASSUNTO (Se ci sono novità)
      if (mangaAggiornati.isNotEmpty) {
        final String riassuntoNomi = mangaAggiornati.join(', ');

        final AndroidNotificationDetails finalDetails =
            AndroidNotificationDetails(
              'sync_result_channel',
              'Nuovi Capitoli',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(
                'Capitoli disponibili per: $riassuntoNomi',
              ),
              icon: '@mipmap/ic_launcher',
              largeIcon: const DrawableResourceAndroidBitmap(
                '@drawable/ic_notification_large',
              ),
            );

        await flutterLocalNotificationsPlugin.show(
          1, // L'ID 1 è per il risultato finale
          'Libreria Aggiornata! 🎉',
          '${mangaAggiornati.length} manga hanno nuovi capitoli.',
          NotificationDetails(android: finalDetails),
        );
      }

      return Future.value(true);
    } catch (err) {
      // In caso di crash (niente internet), spegniamo la barra di caricamento sennò resta bloccata all'infinito
      await flutterLocalNotificationsPlugin.cancel(0);
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ugpvxhsuxspeglueotvr.supabase.co',
    anonKey: 'sb_publishable_135VW_z4BzrYDsbQS-QVTQ_wYiXnm1_',
  );

  final prefs = await SharedPreferences.getInstance();

  // 🌟 FIX: Salviamo lo userId nella cache così il background isolate può leggerlo
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    await prefs.setString('cached_user_id', currentUser.id);
  }

  final bgSync = prefs.getBool('backgroundSync') ?? false;
  final freqStr = prefs.getString('updateFrequency') ?? 'Ogni 6 ore';

  if (!kIsWeb) {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    if (bgSync && freqStr != 'Solo manuale') {
      int hours = 6;
      if (freqStr == 'Ogni ora') hours = 1;
      if (freqStr == 'Ogni 6 ore') hours = 6;
      if (freqStr == 'Ogni 12 ore') hours = 12;
      if (freqStr == 'Ogni giorno') hours = 24;

      Workmanager().registerPeriodicTask(
        "yomu-library-sync",
        "librarySyncTask",
        frequency: Duration(hours: hours),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        initialDelay: const Duration(minutes: 5),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        tag: 'yomu-sync',
      );
    } else {
      Workmanager().cancelByUniqueName("yomu-library-sync");
    }
  }

  final savedColorIndex = prefs.getInt('themeColorIndex') ?? 0;
  final themeColors = [
    const Color(0xFFCA98FF),
    const Color(0xFF82B1FF),
    const Color(0xFF69F0AE),
    const Color(0xFFFF8A80),
    const Color(0xFFFFD180),
  ];
  appColorNotifier.value = themeColors[savedColorIndex];

  final savedTheme = prefs.getString('themeMode') ?? 'Scuro';
  if (savedTheme == 'Chiaro') {
    appThemeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'Predefinito di sistema') {
    appThemeNotifier.value = ThemeMode.system;
  } else {
    appThemeNotifier.value = ThemeMode.dark;
  }

  appBlackNotifier.value = prefs.getBool('pureBlack') ?? true;

  final savedLang = prefs.getString('appLanguage') ?? 'Italiano';
  appLanguageNotifier.value = Locale(savedLang == 'Italiano' ? 'it' : 'en');

  appSystemFontNotifier.value = prefs.getBool('useSystemFont') ?? false;
  final fontScaleStr = prefs.getString('fontScale') ?? 'Normale';
  double scale = 1.0;
  if (fontScaleStr == 'Piccola') scale = 0.85;
  if (fontScaleStr == 'Grande') scale = 1.15;
  if (fontScaleStr == 'Extra grande') scale = 1.30;
  appTextScaleNotifier.value = scale;

  if (currentUser != null) {
    SettingsSyncService.downloadSettings(
      themeNotifier: appThemeNotifier,
      languageNotifier: appLanguageNotifier,
      blackNotifier: appBlackNotifier,
      colorNotifier: appColorNotifier,
      systemFontNotifier: appSystemFontNotifier,
      textScaleNotifier: appTextScaleNotifier,
      themeColors: themeColors,
    );
  }

  runApp(const YomuApp());
}

class YomuApp extends StatelessWidget {
  const YomuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        appColorNotifier,
        appThemeNotifier,
        appBlackNotifier,
        appLanguageNotifier,
        appSystemFontNotifier,
        appTextScaleNotifier,
      ]),
      builder: (context, child) {
        final isDark =
            appThemeNotifier.value == ThemeMode.dark ||
            (appThemeNotifier.value == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        final darkBgColor = appBlackNotifier.value
            ? Colors.black
            : const Color(0xFF121212);

        YomuColors.primary = appColorNotifier.value;
        YomuColors.onPrimary = appColorNotifier.value.computeLuminance() > 0.5
            ? Colors.black87
            : Colors.white;

        if (isDark) {
          YomuColors.surface = darkBgColor;
          YomuColors.surfaceContainer = appBlackNotifier.value
              ? const Color(0xFF121212)
              : const Color(0xFF1E1E1E);
          YomuColors.surfaceContainerHigh = appBlackNotifier.value
              ? const Color(0xFF1A1A1A)
              : const Color(0xFF2B2930);
          YomuColors.surfaceContainerHighest = appBlackNotifier.value
              ? const Color(0xFF222222)
              : const Color(0xFF36343B);
          YomuColors.onSurface = const Color(0xFFE6E1E5);
          YomuColors.onSurfaceVariant = const Color(0xFFCAC4D0);
          YomuColors.outline = const Color(0xFF938F99);
          YomuColors.outlineVariant = const Color(0xFF49454F);
        } else {
          YomuColors.surface = const Color(0xFFF2F2F7);
          YomuColors.surfaceContainer = Colors.white;
          YomuColors.surfaceContainerHigh = Colors.white;
          YomuColors.surfaceContainerHighest = Colors.grey.shade200;
          YomuColors.onSurface = Colors.black87;
          YomuColors.onSurfaceVariant = Colors.grey.shade700;
          YomuColors.outline = Colors.grey.shade400;
          YomuColors.outlineVariant = Colors.grey.shade300;
        }

        final String? fontFamily = appSystemFontNotifier.value
            ? null
            : 'Manrope';

        return MaterialApp(
          title: 'Yomu',
          debugShowCheckedModeBanner: false,
          themeMode: appThemeNotifier.value,
          locale: appLanguageNotifier.value,
          supportedLocales: const [Locale('it', ''), Locale('en', '')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, widget) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(appTextScaleNotifier.value),
              ),
              child: widget!,
            );
          },
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            fontFamily: fontFamily,
            scaffoldBackgroundColor: YomuColors.surface,
            colorScheme: ColorScheme.light(
              primary: appColorNotifier.value,
              surface: YomuColors.surface,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: fontFamily,
            scaffoldBackgroundColor: YomuColors.surface,
            colorScheme: ColorScheme.dark(
              primary: appColorNotifier.value,
              surface: YomuColors.surface,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
