import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_links/app_links.dart';
import 'manga_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'history_screen.dart';
import 'settings/settings_screen.dart';
import '../yomu_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Lingue/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  final String? initialTagId;
  final String? initialTagName;

  const MainScreen({
    super.key,
    this.initialTab = 0,
    this.initialTagId,
    this.initialTagName,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (widget.initialTab != 0) {
      _selectedIndex = widget.initialTab;
    } else {
      _selectedIndex = user == null ? 1 : 0;
    }

    if (user != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cached_user_id', user.id);
      });
    }
    _requestNotificationPermission();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  Future<void> _requestNotificationPermission() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Controlla se l'app è stata avviata tramite link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processUri(initialUri);
        });
      }
    } catch (_) {}

    // Ascolta i link mentre l'app è in background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _processUri(uri);
    });
  }

  void _processUri(Uri uri) async {
    String? mangaId;

    if (uri.scheme == 'yomu' && uri.host == 'manga') {
      // Vecchio sistema yomu://
      mangaId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.host == 'mangadex.org') {
      // Nuovo sistema: intercetta https://mangadex.org/title/xxxxxxxx-xxxx...
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'title') {
        mangaId = uri.pathSegments[1];
      }
    }

    if (mangaId != null && mangaId.isNotEmpty) {
      _openMangaFromId(mangaId);
    }
  }

  Future<void> _openMangaFromId(String id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: YomuColors.primary)),
    );

    try {
      final url = Uri.parse('https://api.mangadex.org/manga/$id?includes[]=cover_art&includes[]=author');
      final r = await http.get(url);
      Navigator.pop(context);

      if (r.statusCode == 200) {
        final data = json.decode(r.body)['data'];
        final title = data['attributes']['title']['en'] ?? data['attributes']['title'].values.firstOrNull ?? 'Sconosciuto';
        String coverUrl = '';
        
        final rels = data['relationships'] as List?;
        if (rels != null) {
          for (var rel in rels) {
            if (rel['type'] == 'cover_art') {
              final fn = rel['attributes']?['fileName'];
              if (fn != null) {
                coverUrl = 'https://uploads.mangadex.org/covers/$id/$fn';
              }
            }
          }
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              manga: data,
              title: title.toString(),
              coverUrl: coverUrl,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appColorNotifier, appThemeNotifier, appBlackNotifier, appLanguageNotifier]),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF0E0E0E),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: YomuColors.surface,
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                LibraryScreen(),
                HomeScreen(
                  initialTagId: widget.initialTagId,
                  initialTagName: widget.initialTagName,
                ),
                HistoryScreen(currentTabIndex: _selectedIndex),
                SettingsScreen(),
              ],
            ),
            bottomNavigationBar: _YomuBottomNav(
              selectedIndex: _selectedIndex,
              onTap: _onTap,
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _YomuBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _YomuBottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    final items = [
      _NavItem(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
        label: loc.translate('nav_library'),
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: loc.translate('nav_explore'),
      ),
      _NavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: loc.translate('nav_history'),
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: loc.translate('nav_settings'),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: YomuColors.surface.withOpacity(0.92),
        border: Border(
          top: BorderSide(color: YomuColors.outlineVariant.withOpacity(0.25)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              return _NavButton(
                item: items[i],
                active: selectedIndex == i,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active
              ? YomuColors.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? item.activeIcon : item.icon,
              color: active ? YomuColors.primary : YomuColors.onSurfaceVariant,
              size: 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: YomuColors.primary,
                          letterSpacing: 0.1,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}