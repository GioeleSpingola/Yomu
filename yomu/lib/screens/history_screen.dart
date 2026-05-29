import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manga_detail_screen.dart';
import '../yomu_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Lingue/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  final int currentTabIndex;
  const HistoryScreen({super.key, this.currentTabIndex = 2});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  String _dateFormat = 'dd/MM/yyyy';
  bool _relativeTimestamps = true;

  // 👇 Variabili per il risparmio dati
  String _imageQuality = 'Alta';
  bool _dataSaver = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchHistory();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dateFormat = prefs.getString('dateFormat') ?? 'dd/MM/yyyy';
        _relativeTimestamps = prefs.getBool('relativeTimestamps') ?? true;
        // 👇 Caricamento preferenze qualità
        _imageQuality = prefs.getString('imageQuality') ?? 'Alta';
        _dataSaver = prefs.getBool('dataSaver') ?? false;
      });
    }
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTabIndex == 2 && oldWidget.currentTabIndex != 2) {
      _loadPrefs();
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final progressData = await Supabase.instance.client
          .from('progressi')
          .select()
          .eq('user_id', user.id)
          .order('last_read', ascending: false)
          .limit(100);

      if (progressData.isEmpty) {
        if (mounted) {
          setState(() {
            _history = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<Map<String, dynamic>> uniqueProgress = [];
      final Set<String> seenMangaIds = {};

      for (var prog in progressData) {
        final mId = prog['manga_id']?.toString();
        if (mId != null && mId.isNotEmpty && mId != 'null') {
          if (seenMangaIds.add(mId)) {
            uniqueProgress.add(prog);
          }
        }
      }

      final topHistory = uniqueProgress.take(30).toList();
      final mangaIds = topHistory.map((e) => e['manga_id'].toString()).toList();

      final chapterIds = topHistory
          .map((e) => e['chapter_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != 'null')
          .toList();

      final idsQuery = mangaIds.map((id) => 'ids[]=$id').join('&');
      final url = Uri.parse(
        'https://api.mangadex.org/manga?includes[]=cover_art&limit=30&$idsQuery',
      );
      final response = await http.get(url);

      Map<String, String> chapterNumbersMap = {};
      if (chapterIds.isNotEmpty) {
        final chapQuery = chapterIds.map((id) => 'ids[]=$id').join('&');
        final chapUrl = Uri.parse(
          'https://api.mangadex.org/chapter?limit=100&$chapQuery',
        );
        final chapResponse = await http.get(chapUrl);
        if (chapResponse.statusCode == 200) {
          final chapData = json.decode(chapResponse.body)['data'] as List;
          for (var c in chapData) {
            chapterNumbersMap[c['id']] =
                c['attributes']['chapter']?.toString() ?? '?';
          }
        }
      }

      if (response.statusCode == 200) {
        final dexData = json.decode(response.body)['data'] as List;
        final dexMap = {for (var m in dexData) m['id']: m};

        final List<Map<String, dynamic>> finalHistory = [];

        for (var prog in topHistory) {
          final mId = prog['manga_id'];
          final cId = prog['chapter_id'];
          final mangaInfo = dexMap[mId];

          if (mangaInfo != null) {
            finalHistory.add({
              'progress': prog,
              'manga': mangaInfo,
              'title': _extractTitle(mangaInfo),
              'coverUrl': _extractCover(mangaInfo),
              'chapterNum': chapterNumbersMap[cId] ?? '?',
            });
          }
        }

        if (mounted) {
          setState(() {
            _history = finalHistory;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Errore cronologia: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractTitle(dynamic manga) {
    final attrs = manga['attributes']['title'] as Map;
    final loc = AppLocalizations.of(context);
    final fallback = loc?.translate('common_unknown') ?? 'Sconosciuto';
    return (attrs['en'] ?? attrs.values.firstOrNull ?? fallback).toString();
  }

  String _extractCover(dynamic manga) {
    final id = manga['id']?.toString() ?? '';
    if (manga['relationships'] == null) return '';
    for (var rel in manga['relationships']) {
      if (rel['type'] == 'cover_art') {
        final fileName = rel['attributes']['fileName'] ?? '';
        if (fileName.isNotEmpty) {
          // 👇 LA MAGIA DEL RISPARMIO DATI ANCHE QUI 👇
          String suffix = '';
          if (_dataSaver || _imageQuality == 'Bassa') {
            suffix = '.256.jpg';
          } else if (_imageQuality == 'Media') {
            suffix = '.512.jpg';
          }
          return 'https://uploads.mangadex.org/covers/$id/$fileName$suffix';
        }
      }
    }
    return '';
  }

  Future<void> _clearHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('progressi')
          .delete()
          .eq('user_id', user.id);
      if (mounted) setState(() => _history = []);
    } catch (_) {}
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final loc = AppLocalizations.of(context)!;
    try {
      String fixedIso = iso;
      if (!fixedIso.endsWith('Z') && !fixedIso.contains('+')) {
        fixedIso += 'Z';
      }
      final dt = DateTime.parse(fixedIso).toLocal();

      String formattedDate;
      if (_dateFormat == 'MM/dd/yyyy') {
        formattedDate =
            '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
      } else if (_dateFormat == 'yyyy-MM-dd') {
        formattedDate =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } else {
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }

      if (_relativeTimestamps) {
        final now = DateTime.now();
        final diff = now.difference(dt);

        if (diff.inMinutes < 60) {
          final min = diff.inMinutes < 0 ? 0 : diff.inMinutes;
          return min == 0
              ? loc.translate('history_just_now')
              : '$min ${loc.translate('history_min_ago')}';
        }
        if (diff.inHours < 24)
          return '${diff.inHours} ${loc.translate('history_hours_ago')}';
        if (diff.inDays == 1) return loc.translate('history_yesterday');
        if (diff.inDays < 7)
          return '${diff.inDays} ${loc.translate('history_days_ago')}';
      }

      return formattedDate;
    } catch (_) {
      return '';
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final loc = AppLocalizations.of(context)!;
    final prog = item['progress'];
    final manga = item['manga'];
    final title = item['title'];
    final coverUrl = item['coverUrl'];
    final chapNum = item['chapterNum'];

    final page = prog['page'] ?? 1;
    final isRead = prog['is_read'] == true;
    final lastRead = _formatDate(prog['last_read']);
    final progressValue = isRead ? 1.0 : ((page as int) / 30.0).clamp(0.0, 1.0);

    final isRecent = index < 2 && !isRead;

    return GestureDetector(
      onTap: () {
        if (manga == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              manga: manga,
              title: title,
              coverUrl: coverUrl,
            ),
          ),
        ).then((_) => _fetchHistory());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: YomuColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isRecent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: YomuColors.secondary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.fromLTRB(isRecent ? 15 : 12, 12, 12, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 80,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          coverUrl.isNotEmpty
                              ? Image.network(
                                  coverUrl,
                                  fit: BoxFit.contain,
                                  color: isRead ? Colors.grey : null,
                                  colorBlendMode: isRead
                                      ? BlendMode.saturation
                                      : null,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: YomuColors.surfaceContainerHigh,
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      color: YomuColors.outline,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: YomuColors.surfaceContainerHigh,
                                  child: Icon(
                                    Icons.image_not_supported_rounded,
                                    color: YomuColors.outline,
                                    size: 20,
                                  ),
                                ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    YomuColors.surfaceContainerHigh.withOpacity(
                                      0.5,
                                    ),
                                  ],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isRead
                                ? YomuColors.onSurfaceVariant
                                : YomuColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              '${loc.translate('history_chapter_short')} $chapNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isRead
                                    ? YomuColors.outline
                                    : YomuColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: YomuColors.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${loc.translate('history_page_short')} $page',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isRead
                                    ? YomuColors.outline
                                    : YomuColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: YomuColors.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              lastRead,
                              style: TextStyle(
                                fontSize: 12,
                                color: YomuColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                        if (!isRead) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: YomuColors.surfaceContainerHigh,
                              valueColor: AlwaysStoppedAnimation(
                                YomuColors.primary,
                              ),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Icon(
                    isRead
                        ? Icons.check_circle_rounded
                        : Icons.play_circle_rounded,
                    color: isRead
                        ? YomuColors.outlineVariant
                        : YomuColors.primary.withOpacity(0.7),
                    size: 26,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: YomuColors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: YomuColors.surface.withOpacity(0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 56,
        leading: Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(
            Icons.menu_book_rounded,
            color: YomuColors.onSurfaceVariant,
          ),
        ),
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
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: YomuColors.onSurfaceVariant,
                size: 22,
              ),
              tooltip: loc.translate('history_clear_tooltip'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: YomuColors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      loc.translate('history_clear_tooltip'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: YomuColors.onSurface,
                      ),
                    ),
                    content: Text(
                      loc.translate('history_clear_confirm'),
                      style: TextStyle(
                        color: YomuColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          loc.translate('common_cancel'),
                          style: TextStyle(color: YomuColors.onSurfaceVariant),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        child: Text(
                          loc.translate('common_clear'),
                          style: TextStyle(color: YomuColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        color: YomuColors.primary,
        backgroundColor: YomuColors.surfaceContainerHighest,
        onRefresh: _fetchHistory,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('history_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: YomuColors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.translate('history_subtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        color: YomuColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: YomuColors.primary),
                ),
              )
            else if (Supabase.instance.client.auth.currentUser == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: YomuColors.onSurfaceVariant.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('history_login_prompt'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: YomuColors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_history.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: YomuColors.onSurfaceVariant.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('history_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: YomuColors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildHistoryItem(_history[i], i),
                    childCount: _history.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
