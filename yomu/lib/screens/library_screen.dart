import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'manga_detail_screen.dart';
import '../yomu_colors.dart';
import '../Lingue/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  User? _user;
  int _filterIndex = 0;
  List<Map<String, dynamic>> _allManga = [];

  String _displayMode = 'compact';
  int _gridColumns = 3;
  bool _autoGrid = true;
  String _sortMode = 'recent';

  bool _showUnreadBadge = true;
  bool _showItemCount = true;
  bool _showProgressBar = true;

  String _imageQuality = 'Alta';
  bool _dataSaver = false;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    _cacheUserId(); // 🌟 FIX: Salva lo userId per il background sync
    _loadSettings();
    _checkSilentSync(); // 🌟 Innesca il check silenzioso all'avvio
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() => _user = data.session?.user);
        _cacheUserId(); // 🌟 Aggiorna anche dopo login/logout
      }
    });
  }

  // 🌟 FIX: Salva lo userId nella cache per il callbackDispatcher in background
  Future<void> _cacheUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      await prefs.setString('cached_user_id', _user!.id);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _displayMode = prefs.getString('displayMode') ?? 'compact';
        _gridColumns = prefs.getInt('gridColumns') ?? 3;
        _autoGrid = prefs.getBool('autoGrid') ?? true;
        _sortMode = prefs.getString('librarySortMode') ?? 'recent';
        _showUnreadBadge = prefs.getBool('showUnreadBadge') ?? true;
        _showItemCount = prefs.getBool('showItemCount') ?? true;
        _showProgressBar = prefs.getBool('showProgressBar') ?? true;

        _imageQuality = prefs.getString('imageQuality') ?? 'Alta';
        _dataSaver = prefs.getBool('dataSaver') ?? false;
      });
    }
  }

  // 🌟 MOTORE DI SINCRONIZZAZIONE INTELLIGENTE
  Future<void> _checkSilentSync() async {
    final prefs = await SharedPreferences.getInstance();

    // Leggiamo le impostazioni dell'utente
    final autoUpdate = prefs.getBool('autoUpdateLibrary') ?? true;
    final freq = prefs.getString('updateFrequency') ?? 'Ogni 6 ore';

    if (!autoUpdate || freq == 'Solo manuale')
      return; // Bloccato dalle impostazioni

    // Calcoliamo il tempo in millisecondi
    int thresholdMs = 21600000; // 6 ore default
    if (freq == 'Ogni ora') thresholdMs = 3600000;
    if (freq == 'Ogni 12 ore') thresholdMs = 43200000;
    if (freq == 'Ogni giorno') thresholdMs = 86400000;

    final lastSync = prefs.getInt('last_sync_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Se è passato il tempo scelto dall'utente, esegue il sync!
    if (now - lastSync > thresholdMs) {
      _syncLibrary(silent: true);
    }
  }

  Future<void> _syncLibrary({bool silent = false}) async {
    if (_user == null) return;
    int updatedMangaCount = 0;

    // Inizializza il plugin delle notifiche per l'aggiornamento manuale
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    try {
      final libraryData = await Supabase.instance.client
          .from('libreria')
          .select(
            'manga_id, title, capitoli_totali',
          ) // Aggiunto il titolo per la notifica
          .eq('user_id', _user!.id);

      int progress = 0;
      int total = libraryData.length;

      for (var item in libraryData) {
        final mangaId = item['manga_id'];
        final titolo = item['title'] ?? 'Manga';
        final vecchiTotali = item['capitoli_totali'] ?? 0;

        if (!silent) {
          int percentuale = total > 0 ? ((progress / total) * 100).toInt() : 0;

          final AndroidNotificationDetails progressDetails =
              AndroidNotificationDetails(
                'manual_sync_channel',
                'Aggiornamento Manuale',
                importance: Importance.low,
                priority: Priority.low,
                showProgress: true,
                maxProgress: total,
                progress: progress,
                ongoing: true,
                onlyAlertOnce: true,
                icon: '@mipmap/ic_launcher',
              );

          // Genera la notifica in tempo reale stile Mihon
          await flutterLocalNotificationsPlugin.show(
            2,
            'Updating library... ($percentuale%)',
            titolo,
            NotificationDetails(android: progressDetails),
          );
        }

        await Future.delayed(const Duration(milliseconds: 350));

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

            if (key.isNotEmpty && !uniqueChapters.containsKey(key)) {
              uniqueChapters[key] = ch;
            }
          }

          final nuoviTotali = uniqueChapters.length;

          if (nuoviTotali > vecchiTotali) {
            await Supabase.instance.client
                .from('libreria')
                .update({'capitoli_totali': nuoviTotali, 'is_new': true})
                .eq('user_id', _user!.id)
                .eq('manga_id', mangaId);

            updatedMangaCount++;
          }
        }
        progress++;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_sync_time',
        DateTime.now().millisecondsSinceEpoch,
      );

      if (!silent) {
        // Rimuove la barra di caricamento al termine
        await flutterLocalNotificationsPlugin.cancel(2);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updatedMangaCount > 0
                    ? 'Libreria aggiornata! $updatedMangaCount manga con nuovi capitoli. 🎉'
                    : 'Libreria aggiornata. Nessun nuovo capitolo.',
                style: TextStyle(
                  color: YomuColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: YomuColors.surfaceContainerHighest,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!silent) {
        await flutterLocalNotificationsPlugin.cancel(2);
      }
      debugPrint('Errore sync: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore di connessione a MangaDex.',
              style: TextStyle(color: YomuColors.onSurface),
            ),
            backgroundColor: YomuColors.surfaceContainerHighest,
          ),
        );
      }
    }
  }

  Future<void> _saveDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayMode', _displayMode);
    await prefs.setInt('gridColumns', _gridColumns);
    await prefs.setBool('autoGrid', _autoGrid);
    await prefs.setBool('showUnreadBadge', _showUnreadBadge);
    await prefs.setBool('showItemCount', _showItemCount);
    await prefs.setBool('showProgressBar', _showProgressBar);
  }

  Future<void> _saveSortSettings(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('librarySortMode', mode);
    setState(() => _sortMode = mode);
  }

  Widget _buildUnauthenticated() {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: YomuColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: YomuColors.surfaceContainerHigh,
                    border: Border.all(color: YomuColors.outlineVariant),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 36,
                    color: YomuColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  loc.translate('library_awaits'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: YomuColors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.translate('library_login_desc'),
                  style: TextStyle(
                    fontSize: 14,
                    color: YomuColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: YomuColors.primary,
                    foregroundColor: YomuColors.onPrimary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ),
                  child: Text(loc.translate('library_login_btn')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final loc = AppLocalizations.of(context)!;
    final labels = [
      loc.translate('library_tab_all'),
      loc.translate('library_tab_reading'),
      loc.translate('library_tab_completed'),
      loc.translate('library_tab_planned'),
      loc.translate('library_tab_on_hold'),
      loc.translate('library_tab_dropped'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final active = _filterIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: active
                    ? YomuColors.secondary
                    : YomuColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.black : YomuColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSortSettingsSheet() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: YomuColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: YomuColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              loc.translate('explore_sort_by'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: YomuColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _sortTile(
              loc.translate('library_sort_recent'),
              'recent',
              Icons.schedule_rounded,
            ),
            _sortTile(
              loc.translate('library_sort_last_read'),
              'last_read',
              Icons.history_rounded,
            ),
            _sortTile(
              loc.translate('library_sort_unread'),
              'unread',
              Icons.mark_chat_unread_rounded,
            ),
            _sortTile(
              loc.translate('library_sort_az'),
              'alpha_asc',
              Icons.sort_by_alpha_rounded,
            ),
            _sortTile(
              loc.translate('library_sort_za'),
              'alpha_desc',
              Icons.sort_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(String title, String value, IconData icon) {
    final isSel = _sortMode == value;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        _saveSortSettings(value);
      },
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: isSel ? YomuColors.primary : YomuColors.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSel ? YomuColors.primary : YomuColors.onSurface,
          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSel
          ? Icon(Icons.check_circle_rounded, color: YomuColors.primary)
          : null,
    );
  }

  void _showDisplaySettingsSheet() {
    final loc = AppLocalizations.of(context)!;
    _loadSettings().then((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (ctx, setModal) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: YomuColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    loc.translate('display_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: YomuColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc.translate('display_mode'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: YomuColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _displayModeChip(
                        setModal,
                        'compact',
                        loc.translate('display_grid_compact'),
                        Icons.grid_view_rounded,
                      ),
                      _displayModeChip(
                        setModal,
                        'comfortable',
                        loc.translate('display_grid_comfortable'),
                        Icons.grid_on_rounded,
                      ),
                      _displayModeChip(
                        setModal,
                        'list',
                        loc.translate('display_list'),
                        Icons.view_list_rounded,
                      ),
                    ],
                  ),
                  if (_displayMode != 'list') ...[
                    const SizedBox(height: 24),
                    Divider(
                      color: YomuColors.outlineVariant.withOpacity(0.3),
                      height: 1,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.translate('display_columns'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: YomuColors.primary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              loc.translate('display_auto'),
                              style: TextStyle(
                                fontSize: 14,
                                color: YomuColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch(
                              value: _autoGrid,
                              activeColor: YomuColors.primary,
                              onChanged: (v) {
                                setState(() => _autoGrid = v);
                                setModal(() => _autoGrid = v);
                                _saveDisplaySettings();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Opacity(
                      opacity: _autoGrid ? 0.4 : 1.0,
                      child: IgnorePointer(
                        ignoring: _autoGrid,
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: YomuColors.primary,
                                inactiveTrackColor: YomuColors.outlineVariant
                                    .withOpacity(0.5),
                                thumbColor: YomuColors.primary,
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _gridColumns.toDouble(),
                                min: 2,
                                max: 6,
                                divisions: 4,
                                label: _gridColumns.toString(),
                                onChanged: (v) {
                                  setState(() => _gridColumns = v.toInt());
                                  setModal(() => _gridColumns = v.toInt());
                                  _saveDisplaySettings();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Divider(
                    color: YomuColors.outlineVariant.withOpacity(0.3),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('display_overlays'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: YomuColors.primary,
                    ),
                  ),
                  _buildCheckboxTile(
                    loc.translate('display_unread_badge'),
                    _showUnreadBadge,
                    (v) {
                      setState(() => _showUnreadBadge = v ?? true);
                      setModal(() => _showUnreadBadge = v ?? true);
                      _saveDisplaySettings();
                    },
                  ),
                  _buildCheckboxTile(
                    loc.translate('display_progress_bar'),
                    _showProgressBar,
                    (v) {
                      setState(() => _showProgressBar = v ?? true);
                      setModal(() => _showProgressBar = v ?? true);
                      _saveDisplaySettings();
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('display_other'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: YomuColors.primary,
                    ),
                  ),
                  _buildCheckboxTile(
                    loc.translate('display_item_count'),
                    _showItemCount,
                    (v) {
                      setState(() => _showItemCount = v ?? true);
                      setModal(() => _showItemCount = v ?? true);
                      _saveDisplaySettings();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCheckboxTile(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: YomuColors.primary,
                side: BorderSide(color: YomuColors.outlineVariant, width: 2),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: YomuColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _displayModeChip(
    StateSetter setModal,
    String mode,
    String label,
    IconData icon,
  ) {
    final isSel = _displayMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _displayMode = mode);
        setModal(() => _displayMode = mode);
        _saveDisplaySettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? YomuColors.primary : YomuColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel
                ? YomuColors.primary
                : YomuColors.outlineVariant.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSel ? YomuColors.onPrimary : YomuColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSel
                    ? YomuColors.onPrimary
                    : YomuColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMangaCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Sconosciuto';

    String coverUrl = item['cover_url'] ?? '';
    if (coverUrl.isNotEmpty &&
        coverUrl.contains('uploads.mangadex.org/covers/')) {
      coverUrl = coverUrl.replaceAll('.256.jpg', '').replaceAll('.512.jpg', '');

      if (_dataSaver || _imageQuality == 'Bassa') {
        coverUrl += '.256.jpg';
      } else if (_imageQuality == 'Media') {
        coverUrl += '.512.jpg';
      }
    }

    final int totali = item['capitoli_totali'] ?? 0;
    final int letti = item['capitoli_letti'] ?? 0;
    final int daLeggere = totali - letti;
    final double progress = totali > 0 ? (letti / totali).clamp(0.0, 1.0) : 0.0;

    // 🌟 QUI MOSTRIAMO IL BADGE SE CI SONO NUOVI CAPITOLI!
    final isNew = item['is_new'] == true;

    List<Widget> overlays = [
      if (isNew)
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: YomuColors.secondary.withOpacity(0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      if (_showUnreadBadge && daLeggere > 0)
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: YomuColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              daLeggere.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: YomuColors.onPrimary,
              ),
            ),
          ),
        ),
      if (_showProgressBar)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            color: Colors.black.withOpacity(0.4),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: YomuColors.primary),
            ),
          ),
        ),
    ];

    Widget content;
    if (_displayMode == 'list') {
      content = Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 85,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl:
                          coverUrl, // ⚠️ Usa 'coverUrl' se sei nel file library_screen.dart
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) =>
                          Container(color: YomuColors.surfaceContainerHigh),
                      errorWidget: (context, url, error) =>
                          Container(color: YomuColors.surfaceContainerHigh),
                    )
                  else
                    Container(color: YomuColors.surfaceContainerHigh),
                  ...overlays,
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: YomuColors.onSurface,
              ),
            ),
          ),
        ],
      );
    } else if (_displayMode == 'comfortable') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl:
                          coverUrl, // ⚠️ Usa 'coverUrl' se sei nel file library_screen.dart
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) =>
                          Container(color: YomuColors.surfaceContainerHigh),
                      errorWidget: (context, url, error) =>
                          Container(color: YomuColors.surfaceContainerHigh),
                    )
                  else
                    Container(color: YomuColors.surfaceContainerHigh),
                  ...overlays,
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: YomuColors.onSurface,
                height: 1.2,
              ),
            ),
          ),
        ],
      );
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl:
                    coverUrl, // ⚠️ Usa 'coverUrl' se sei nel file library_screen.dart
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) =>
                    Container(color: YomuColors.surfaceContainerHigh),
                errorWidget: (context, url, error) =>
                    Container(color: YomuColors.surfaceContainerHigh),
              )
            else
              Container(color: YomuColors.surfaceContainerHigh),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            ...overlays,
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        // 🌟 Trasformiamo l'onTap in asincrono
        // Se il manga ha il badge NEW, aggiorniamo il DB prima di cambiare schermata
        if (isNew) {
          try {
            // Usiamo 'await' e filtriamo direttamente sul campo 'id' (chiave primaria della riga),
            // che è istantaneo e sicuro al 100%
            await Supabase.instance.client
                .from('libreria')
                .update({'is_new': false})
                .eq('id', item['id']);
          } catch (e) {
            debugPrint('Errore nel reset del badge NEW: $e');
          }
        }

        if (!mounted) return;

        // Ora che il database è aggiornato, navighiamo nei dettagli
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              manga: {
                'id': item['manga_id'],
                'attributes': {
                  'title': {'en': title},
                },
              },
              title: title,
              coverUrl: item['cover_url'] ?? '',
            ),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
      },
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return _buildUnauthenticated();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: YomuColors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: YomuColors.surface.withOpacity(0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Yomu',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            fontStyle: FontStyle.italic,
            color: YomuColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sort_rounded, color: YomuColors.onSurfaceVariant),
            onPressed: _showSortSettingsSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.display_settings_rounded,
              color: YomuColors.onSurfaceVariant,
            ),
            onPressed: _showDisplaySettingsSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: YomuColors.onSurfaceVariant,
            ),
            onPressed: () => showSearch(
              context: context,
              delegate: MangaSearchDelegate(_allManga),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('libreria')
            .stream(primaryKey: ['id'])
            .eq('user_id', _user!.id),
        builder: (context, snapshot) {
          if (snapshot.hasData) _allManga = snapshot.data!;

          List<Map<String, dynamic>> savedManga = _allManga.where((item) {
            if (_filterIndex == 0) return true;
            final status = item['status'] as String?;
            switch (_filterIndex) {
              case 1:
                return status == 'reading' || status == null;
              case 2:
                return status == 'completed';
              case 3:
                return status == 'plan_to_read';
              case 4:
                return status == 'on_hold';
              case 5:
                return status == 'dropped';
              default:
                return true;
            }
          }).toList();

          savedManga.sort((a, b) {
            int cmp = 0;
            if (_sortMode == 'alpha_asc') {
              cmp = (a['title'] ?? '').toString().toLowerCase().compareTo(
                (b['title'] ?? '').toString().toLowerCase(),
              );
            } else if (_sortMode == 'alpha_desc') {
              cmp = (b['title'] ?? '').toString().toLowerCase().compareTo(
                (a['title'] ?? '').toString().toLowerCase(),
              );
            } else if (_sortMode == 'last_read') {
              final dateA =
                  DateTime.tryParse(a['last_read'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  DateTime.tryParse(b['last_read'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              cmp = dateB.compareTo(dateA);
            } else if (_sortMode == 'unread') {
              final unreadA =
                  (a['capitoli_totali'] ?? 0) - (a['capitoli_letti'] ?? 0);
              final unreadB =
                  (b['capitoli_totali'] ?? 0) - (b['capitoli_letti'] ?? 0);
              cmp = unreadB.compareTo(unreadA);
            } else {
              final dateA =
                  DateTime.tryParse(a['created_at'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  DateTime.tryParse(b['created_at'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              cmp = dateB.compareTo(dateA);
            }
            return cmp != 0
                ? cmp
                : (a['title'] ?? '').toString().compareTo(
                    (b['title'] ?? '').toString(),
                  );
          });

          // 🌟 IL REFRESH INDICATOR CHE AVVOLGE LA LIBRERIA
          return RefreshIndicator(
            color: YomuColors.primary,
            backgroundColor: YomuColors.surfaceContainerHigh,
            edgeOffset: 120.0,
            onRefresh: _handleManualRefresh,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Necessario per tirare sempre giù
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
                SliverToBoxAdapter(child: _buildFilterChips()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                if (_showItemCount)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${savedManga.length} ${loc.translate('library_manga_count')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: YomuColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _allManga.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (savedManga.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 56,
                            color: YomuColors.onSurfaceVariant.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loc.translate('library_empty'),
                            style: TextStyle(
                              color: YomuColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_displayMode == 'list')
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildMangaCard(savedManga[i]),
                        ),
                        childCount: savedManga.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildMangaCard(savedManga[i]),
                        childCount: savedManga.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _autoGrid
                            ? (MediaQuery.of(context).size.width ~/ 110).clamp(
                                2,
                                6,
                              )
                            : _gridColumns,
                        childAspectRatio: _calculateRatio(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: _displayMode == 'comfortable'
                            ? 18
                            : 10,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🌟 FIX: Ora esegue il sync direttamente invece di delegare a Workmanager,
  // così la UI si aggiorna in tempo reale con il progresso e i risultati.
  Future<void> _handleManualRefresh() async {
    await _syncLibrary(silent: false);
  }

  double _calculateRatio() {
    int cols = _autoGrid
        ? (MediaQuery.of(context).size.width ~/ 110).clamp(2, 6)
        : _gridColumns;
    double r = _displayMode == 'comfortable' ? 0.52 : 0.65;
    if (cols == 2) r += 0.15;
    if (cols >= 4) r -= (0.05 * (cols - 3));
    return r;
  }
}

class MangaSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> allManga;
  MangaSearchDelegate(this.allManga);
  @override
  ThemeData appBarTheme(BuildContext context) => ThemeData(
    appBarTheme: AppBarTheme(
      backgroundColor: YomuColors.surface,
      foregroundColor: YomuColors.onSurface,
      elevation: 0,
    ),
    scaffoldBackgroundColor: YomuColors.surface,
  );
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
  @override
  Widget buildResults(BuildContext context) => _results();
  @override
  Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() {
    final list = allManga
        .where(
          (m) => (m['title'] ?? '').toString().toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(list[i]['title'] ?? 'Sconosciuto'),
        onTap: () {},
      ),
    );
  }
}
