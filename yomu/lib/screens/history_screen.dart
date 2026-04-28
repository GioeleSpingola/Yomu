import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manga_detail_screen.dart';
import '../yomu_colors.dart';

class HistoryScreen extends StatefulWidget {
  final int currentTabIndex;
  const HistoryScreen({super.key, this.currentTabIndex = 2});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se l'utente ha appena cliccato sulla scheda 2 (Cronologia), aggiorniamo i dati in background!
    if (widget.currentTabIndex == 2 && oldWidget.currentTabIndex != 2) {
      _fetchHistory();
    }
  }

  // ─── Logic ────────────────────────────────────────────────────────────────
  Future<void> _fetchHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Prendiamo gli ultimi progressi dell'utente
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

      // 2. Estraiamo i manga UNICI (vogliamo mostrare solo l'ultimo capitolo letto per manga)
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

      // Prendiamo i primi 30 manga recenti
      final topHistory = uniqueProgress.take(30).toList();
      final mangaIds = topHistory.map((e) => e['manga_id'].toString()).toList();

      // Prepariamo anche gli ID dei capitoli
      final chapterIds = topHistory
          .map((e) => e['chapter_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != 'null')
          .toList();

      // 3. Batch Fetch da MangaDex per I MANGA
      final idsQuery = mangaIds.map((id) => 'ids[]=$id').join('&');
      final url = Uri.parse(
        'https://api.mangadex.org/manga?includes[]=cover_art&limit=30&$idsQuery',
      );
      final response = await http.get(url);

      // 4. Batch Fetch da MangaDex per I CAPITOLI (Per avere il numero reale del capitolo!)
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
            // Se il chapter è null (es. nei oneshot), mettiamo un '?'
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
              'chapterNum':
                  chapterNumbersMap[cId] ??
                  '?', // Aggiungiamo il numero del capitolo!
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
    return (attrs['en'] ?? attrs.values.firstOrNull ?? 'Sconosciuto')
        .toString();
  }

  String _extractCover(dynamic manga) {
    final id = manga['id']?.toString() ?? '';
    if (manga['relationships'] == null) return '';
    for (var rel in manga['relationships']) {
      if (rel['type'] == 'cover_art') {
        final fileName = rel['attributes']['fileName'] ?? '';
        if (fileName.isNotEmpty) {
          return 'https://uploads.mangadex.org/covers/$id/$fileName';
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
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
      if (diff.inHours < 24) return '${diff.inHours} ore fa';
      if (diff.inDays == 1) return 'Ieri';
      if (diff.inDays < 7) return '${diff.inDays} giorni fa';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
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
          color: Colors.black,
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
                  decoration: const BoxDecoration(
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
                  // Cover thumbnail
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
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: YomuColors.outline,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: YomuColors.surfaceContainerHigh,
                                  child: const Icon(
                                    Icons.image_not_supported_rounded,
                                    color: YomuColors.outline,
                                    size: 20,
                                  ),
                                ),
                          // Gradient bottom
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.5),
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

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Manrope',
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
                            // Adesso mostriamo Capitolo e Pagina!
                            Text(
                              'Cap. $chapNum',
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
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: YomuColors.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pag. $page',
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
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: YomuColors.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              lastRead,
                              style: const TextStyle(
                                fontSize: 12,
                                color: YomuColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                        // Progress bar (only when in progress)
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

                  // Play icon
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
    return Scaffold(
      backgroundColor: YomuColors.surface,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: YomuColors.surface.withOpacity(0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 56,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(
            Icons.menu_book_rounded,
            color: YomuColors.onSurfaceVariant,
          ),
        ),
        title: Text(
          'Yomu',
          style: TextStyle(
            fontFamily: 'Manrope',
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
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: YomuColors.onSurfaceVariant,
                size: 22,
              ),
              tooltip: 'Cancella cronologia',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: YomuColors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Cancella cronologia',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        color: YomuColors.onSurface,
                      ),
                    ),
                    content: const Text(
                      'Vuoi davvero rimuovere tutti i progressi di lettura?',
                      style: TextStyle(
                        color: YomuColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Annulla',
                          style: TextStyle(color: YomuColors.onSurfaceVariant),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        child: const Text(
                          'Cancella',
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
                    const Text(
                      'Cronologia',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        color: YomuColors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Riprendi da dove ti eri fermato.',
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
                      const Text(
                        'Accedi per vedere\nla tua cronologia.',
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
                      const Text(
                        'Nessuna lettura recente.\nEsplora e inizia a leggere!',
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
