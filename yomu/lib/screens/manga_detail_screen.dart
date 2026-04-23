import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'reader_screen.dart';
import '../yomu_colors.dart';

class MangaDetailScreen extends StatefulWidget {
  final dynamic manga;
  final String title;
  final String coverUrl;

  const MangaDetailScreen({
    super.key,
    required this.manga,
    required this.title,
    required this.coverUrl,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final List<dynamic> _uniqueChapters = [];
  final Set<String> _seenChapters = {};
  bool _isLoadingChapters = true;
  bool _isLoadingMoreChapters = false;
  bool _hasMoreChapters = true;
  int _offset = 0;
  final int _limit = 100;
  final ScrollController _scrollController = ScrollController();

  bool _isInLibrary = false;
  final Set<String> _readChapters = {};
  String? _lastReadChapterId;
  String _localLibraryStatus = 'reading';
  int _lastReadPage = 1;
  final Map<String, int> _chapterPages = {};

  bool _selectionMode = false;
  final Set<String> _selectedChapterIds = {};

  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchChapters();
    _checkLibraryStatus();
    _fetchProgress();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoadingMoreChapters &&
          _hasMoreChapters) {
        _fetchMoreChapters();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'reading':
        return 'In Lettura';
      case 'plan_to_read':
        return 'In Programma';
      case 'completed':
        return 'Completato';
      case 'on_hold':
        return 'In Pausa';
      case 'dropped':
        return 'Abbandonato';
      default:
        return 'In Lettura';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'reading':
        return Icons.menu_book_rounded;
      case 'plan_to_read':
        return Icons.schedule_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'on_hold':
        return Icons.pause_circle_filled_rounded;
      case 'dropped':
        return Icons.cancel_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  void _showStatusDialog() {
    if (!_isInLibrary) {
      _snack('Aggiungi prima il manga alla libreria!');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: YomuColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: YomuColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'La tua libreria',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: YomuColors.onSurface,
                ),
              ),
            ),
            _statusTile('In Lettura', 'reading', Icons.menu_book_rounded),
            _statusTile('In Programma', 'plan_to_read', Icons.schedule_rounded),
            _statusTile('Completato', 'completed', Icons.check_circle_rounded),
            _statusTile(
              'In Pausa',
              'on_hold',
              Icons.pause_circle_filled_rounded,
            ),
            _statusTile('Abbandonato', 'dropped', Icons.cancel_rounded),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(String title, String statusValue, IconData icon) {
    final isSelected = _localLibraryStatus == statusValue;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? YomuColors.primary : YomuColors.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? YomuColors.primary : YomuColors.onSurface,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: YomuColors.primary)
          : null,
      onTap: () async {
        Navigator.pop(context);
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        try {
          final response = await Supabase.instance.client
              .from('libreria')
              .update({'status': statusValue})
              .eq('user_id', user.id)
              .eq('manga_id', widget.manga['id'].toString())
              .select();

          if (response.isEmpty) {
            _snack(
              'Permesso negato dal Database (Controlla le RLS!)',
              isError: true,
            );
            return;
          }

          setState(() {
            _localLibraryStatus = statusValue;
          });
          _snack('Stato aggiornato a "$title"');
        } catch (e) {
          _snack('Errore durante l\'aggiornamento', isError: true);
        }
      },
    );
  }

  Future<void> _checkLibraryStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final r = await Supabase.instance.client
          .from('libreria')
          .select()
          .eq('user_id', user.id)
          .eq('manga_id', widget.manga['id'])
          .maybeSingle();
      if (mounted && r != null) {
        setState(() {
          _isInLibrary = true;
          _localLibraryStatus = r['status'] ?? 'reading';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isInLibrary = false);
    }
  }

  Future<void> _fetchProgress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('progressi')
          .select('chapter_id, is_read, page, last_read')
          .eq('user_id', user.id)
          .eq('manga_id', widget.manga['id'])
          .order('last_read', ascending: false);
      if (mounted) {
        setState(() {
          _readChapters.clear();
          _chapterPages.clear();
          if (rows.isNotEmpty) {
            _lastReadChapterId = rows.first['chapter_id'];
            _lastReadPage = rows.first['page'] ?? 1;
          }
          for (var r in rows) {
            if (r['is_read'] == true) _readChapters.add(r['chapter_id']);
            _chapterPages[r['chapter_id']] = r['page'] ?? 1;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchChapters() async {
    final url = Uri.parse(
      'https://api.mangadex.org/manga/${widget.manga['id']}/feed'
      '?translatedLanguage[]=en&order[chapter]=desc'
      '&limit=$_limit&offset=$_offset',
    );
    try {
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        for (var ch in data['data'] as List) {
          final id = ch['attributes']['chapter'] ?? ch['id'];
          if (_seenChapters.add(id)) _uniqueChapters.add(ch);
        }
        if (mounted) {
          setState(() {
            _isLoadingChapters = false;
            if ((data['data'] as List).length < _limit) {
              _hasMoreChapters = false;
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingChapters = false);
    }
  }

  Future<void> _fetchMoreChapters() async {
    setState(() => _isLoadingMoreChapters = true);
    _offset += _limit;
    final url = Uri.parse(
      'https://api.mangadex.org/manga/${widget.manga['id']}/feed'
      '?translatedLanguage[]=en&order[chapter]=desc'
      '&limit=$_limit&offset=$_offset',
    );
    try {
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        for (var ch in data['data'] as List) {
          final id = ch['attributes']['chapter'] ?? ch['id'];
          if (_seenChapters.add(id)) _uniqueChapters.add(ch);
        }
        if (mounted) {
          setState(() {
            _isLoadingMoreChapters = false;
            if ((data['data'] as List).length < _limit) {
              _hasMoreChapters = false;
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMoreChapters = false);
    }
  }

  Future<void> _toggleLibrary() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (Supabase.instance.client.auth.currentUser == null) return;
      await _checkLibraryStatus();
    }
    try {
      if (_isInLibrary) {
        await Supabase.instance.client
            .from('libreria')
            .delete()
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
            .eq('manga_id', widget.manga['id']);
        if (mounted) {
          setState(() => _isInLibrary = false);
          _snack('Rimosso dalla libreria');
        }
      } else {
        await Supabase.instance.client.from('libreria').insert({
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'manga_id': widget.manga['id'],
          'title': widget.title,
          'cover_url': widget.coverUrl,
          'status': 'reading',
        });
        if (mounted) {
          setState(() {
            _isInLibrary = true;
            _localLibraryStatus = 'reading';
          });
          _snack('Aggiunto alla libreria!');
        }
      }
    } catch (e) {
      if (mounted) _snack('Errore: $e', isError: true);
    }
  }

  Future<void> _setChapterRead(String chapId, bool read) async {
    await _bulkSetRead([chapId], read);
  }

  Future<void> _bulkSetRead(List<String> ids, bool read) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || ids.isEmpty) return;

    try {
      for (var i = 0; i < ids.length; i += 100) {
        final end = (i + 100 < ids.length) ? i + 100 : ids.length;
        final subIds = ids.sublist(i, end);

        await Supabase.instance.client
            .from('progressi')
            .delete()
            .eq('user_id', user.id)
            .filter('chapter_id', 'in', subIds);

        if (read) {
          final List<Map<String, dynamic>> payload = subIds
              .map(
                (id) => {
                  'user_id': user.id,
                  'manga_id': widget.manga['id'],
                  'chapter_id': id,
                  'page': 1,
                  'is_read': true,
                  'last_read': DateTime.now().toUtc().toIso8601String(),
                },
              )
              .toList();

          await Supabase.instance.client.from('progressi').insert(payload);
        }
      }

      if (_isInLibrary && _uniqueChapters.isNotEmpty) {
        if (read) {
          final mangaPubStatus = widget.manga['attributes']['status'];
          final latestChapterId = _uniqueChapters.first['id'];

          if ((mangaPubStatus == 'completed' ||
                  mangaPubStatus == 'cancelled') &&
              (ids.contains(latestChapterId) ||
                  _readChapters.contains(latestChapterId))) {
            await Supabase.instance.client
                .from('libreria')
                .update({'status': 'completed'})
                .eq('user_id', user.id)
                .eq('manga_id', widget.manga['id']);

            if (mounted) setState(() => _localLibraryStatus = 'completed');
          }
        } else {
          await Supabase.instance.client
              .from('libreria')
              .update({'status': 'reading'})
              .eq('user_id', user.id)
              .eq('manga_id', widget.manga['id']);

          if (mounted) setState(() => _localLibraryStatus = 'reading');
        }
      }

      if (mounted) {
        setState(() {
          if (read) {
            _readChapters.addAll(ids);
          } else {
            _readChapters.removeAll(ids);
            for (final id in ids) {
              _chapterPages.remove(id);
            }
          }
        });
        _snack(
          read
              ? '${ids.length} capitoli segnati come letti'
              : '${ids.length} capitoli non letti',
        );
      }
    } catch (e) {
      if (mounted) _snack('Errore nel salvataggio. Riprova.', isError: true);
    }
  }

  Future<void> _markOlderChaptersAsRead(int index, bool read) async {
    final currentChap = _uniqueChapters[index];
    final currentChapNumStr = currentChap['attributes']['chapter'];
    final currentChapNum = double.tryParse(currentChapNumStr ?? '') ?? 0.0;

    _snack(read ? 'Recupero capitoli da segnare...' : 'Recupero capitoli...');

    List<String> targetIds = [];
    int fetchOffset = 0;
    bool hasMore = true;

    while (hasMore) {
      final url = Uri.parse(
        'https://api.mangadex.org/manga/${widget.manga['id']}/feed'
        '?translatedLanguage[]=en&order[chapter]=desc'
        '&limit=500&offset=$fetchOffset',
      );
      try {
        final r = await http.get(url);
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          final list = data['data'] as List;
          for (var ch in list) {
            final chapNumStr = ch['attributes']['chapter'];
            final chapNum = double.tryParse(chapNumStr ?? '') ?? 0.0;

            if (chapNumStr != null && chapNum < currentChapNum) {
              targetIds.add(ch['id']);
            }
          }
          if (list.length < 500) {
            hasMore = false;
          } else {
            fetchOffset += 500;
          }
        } else {
          hasMore = false;
        }
      } catch (_) {
        hasMore = false;
      }
    }

    if (targetIds.isNotEmpty) {
      await _bulkSetRead(targetIds, read);
    } else {
      _snack('Nessun capitolo precedente trovato.');
    }
  }

  void _enterSelectionMode(String firstId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedChapterIds
        ..clear()
        ..add(firstId);
    });
  }

  void _exitSelectionMode() => setState(() {
    _selectionMode = false;
    _selectedChapterIds.clear();
  });

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedChapterIds.contains(id)) {
        _selectedChapterIds.remove(id);
        if (_selectedChapterIds.isEmpty) _selectionMode = false;
      } else {
        _selectedChapterIds.add(id);
      }
    });
  }

  void _showChapterContextMenu(int index) {
    final chapter = _uniqueChapters[index];
    final chapId = chapter['id'] as String;
    final chapNum = chapter['attributes']['chapter']?.toString() ?? '?';
    final isRead = _readChapters.contains(chapId);

    final allIds = _uniqueChapters.map((c) => c['id'] as String).toList();
    final otherIds = allIds.where((id) => id != chapId).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: YomuColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: YomuColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: YomuColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      chapNum,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: YomuColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Capitolo $chapNum',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: YomuColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: YomuColors.outlineVariant.withOpacity(0.25),
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            const SizedBox(height: 4),

            _ctxTile(
              icon: isRead
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.check_circle_rounded,
              label: isRead ? 'Segna come non letto' : 'Segna come letto',
              color: isRead ? YomuColors.onSurfaceVariant : YomuColors.primary,
              onTap: () {
                Navigator.pop(context);
                _setChapterRead(chapId, !isRead);
              },
            ),

            _ctxTile(
              icon: Icons.checklist_rounded,
              label: 'Segna precedenti come letti',
              onTap: () {
                Navigator.pop(context);
                _markOlderChaptersAsRead(index, true);
              },
            ),
            _ctxTile(
              icon: Icons.remove_done_rounded,
              label: 'Segna precedenti come non letti',
              onTap: () {
                Navigator.pop(context);
                _markOlderChaptersAsRead(index, false);
              },
            ),

            Divider(
              color: YomuColors.outlineVariant.withOpacity(0.25),
              height: 12,
              indent: 20,
              endIndent: 20,
            ),

            _ctxTile(
              icon: Icons.select_all_rounded,
              label: 'Seleziona tutti',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectionMode = true;
                  _selectedChapterIds
                    ..clear()
                    ..addAll(allIds);
                });
              },
            ),
            _ctxTile(
              icon: Icons.deselect_rounded,
              label: 'Seleziona tutti gli altri',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectionMode = true;
                  _selectedChapterIds
                    ..clear()
                    ..addAll(otherIds);
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _ctxTile({
    required IconData icon,
    required String label,
    Color color = YomuColors.onSurface,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      dense: true,
      minVerticalPadding: 2,
    );
  }

  Widget _buildSelectionBar() {
    final sel = _selectedChapterIds.toList();
    final allRead = sel.every((id) => _readChapters.contains(id));
    final anyRead = sel.any((id) => _readChapters.contains(id));

    return Container(
      color: YomuColors.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: YomuColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${sel.length} selezionati',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: YomuColors.primary,
                ),
              ),
            ),
            const Spacer(),
            if (!allRead)
              _selBtn(
                icon: Icons.check_circle_rounded,
                label: 'Letti',
                onTap: () {
                  _bulkSetRead(sel, true);
                  _exitSelectionMode();
                },
              ),
            if (anyRead) ...[
              const SizedBox(width: 8),
              _selBtn(
                icon: Icons.radio_button_unchecked_rounded,
                label: 'Non letti',
                color: YomuColors.onSurfaceVariant,
                onTap: () {
                  _bulkSetRead(sel, false);
                  _exitSelectionMode();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selBtn({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? YomuColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activeColor, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: YomuColors.onSurface, fontSize: 13),
        ),
        backgroundColor: isError
            ? YomuColors.error.withOpacity(0.15)
            : YomuColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 0,
      ),
    );
  }

  // REINSERITA LA FUNZIONE _formatDate
  String? _formatDate(dynamic raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw as String).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays < 1) return 'Oggi';
      if (diff.inDays == 1) return 'Ieri';
      if (diff.inDays < 7) return '${diff.inDays}g fa';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}sett fa';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return null;
    }
  }

  Widget _buildHeader(
    String description,
    String status,
    String? lastChapter,
    List<String> tags,
    String? author,
  ) {
    // Verifichiamo se l'utente è "in pari" controllando se l'ultimo capitolo disponibile è stato letto
    bool isCaughtUp = false;
    if (_uniqueChapters.isNotEmpty) {
      final readCount = _uniqueChapters
          .where((c) => _readChapters.contains(c['id']))
          .length;
      isCaughtUp = readCount == _uniqueChapters.length;
    }

    return SliverToBoxAdapter(
      child: Stack(
        children: [
          if (widget.coverUrl.isNotEmpty)
            SizedBox(
              height: 280,
              width: double.infinity,
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), YomuColors.surface],
                ).createShader(rect),
                blendMode: BlendMode.darken,
                child: Image.network(
                  widget.coverUrl,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.55),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 88, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Hero(
                      tag: widget.manga['id'] ?? widget.title,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.coverUrl.isNotEmpty
                            ? Image.network(
                                widget.coverUrl,
                                width: 110,
                                height: 165,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _coverPlaceholder(),
                              )
                            : _coverPlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _pill(
                                status,
                                bg: YomuColors.surfaceContainerHighest,
                                fg: YomuColors.onSurfaceVariant,
                              ),
                              if (lastChapter != null)
                                _pill(
                                  'Cap. $lastChapter',
                                  bg: YomuColors.primary.withOpacity(0.15),
                                  fg: YomuColors.primary,
                                ),
                            ],
                          ),

                          if (author != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  size: 13,
                                  color: YomuColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: YomuColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: tags
                                  .take(6)
                                  .map(
                                    (t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: YomuColors.outlineVariant
                                              .withOpacity(0.5),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        t,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: YomuColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: YomuColors.onSurface,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 14),

                if (description.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => setState(() => _descExpanded = !_descExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 250),
                          crossFadeState: _descExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Text(
                            description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: YomuColors.onSurfaceVariant,
                              height: 1.55,
                            ),
                          ),
                          secondChild: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: YomuColors.onSurfaceVariant,
                              height: 1.55,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _descExpanded ? 'Mostra meno' : 'Leggi di più',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: YomuColors.primary,
                              ),
                            ),
                            Icon(
                              _descExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: YomuColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_isInLibrary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: _showStatusDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: YomuColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: YomuColors.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _localLibraryStatus == 'completed'
                                  ? Icons.check_circle_rounded
                                  : Icons.menu_book_rounded,
                              size: 16,
                              color: YomuColors.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Libreria: ',
                              style: TextStyle(
                                color: YomuColors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _getStatusText(_localLibraryStatus),
                              style: const TextStyle(
                                color: YomuColors.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: YomuColors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (!_isLoadingChapters && _uniqueChapters.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: isCaughtUp
                            ? FilledButton.icon(
                                onPressed: null, // Disabilita il pulsante
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  status == 'COMPLETED'
                                      ? 'Completato'
                                      : 'Sei in pari',
                                ),
                                style: FilledButton.styleFrom(
                                  disabledBackgroundColor:
                                      YomuColors.surfaceContainerHighest,
                                  disabledForegroundColor:
                                      YomuColors.onSurfaceVariant,
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: _startReading,
                                icon: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _lastReadChapterId != null
                                      ? 'Riprendi'
                                      : 'Inizia a leggere',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: YomuColors.primary,
                                  foregroundColor: YomuColors.onPrimary,
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      _squareBtn(
                        icon: _isInLibrary
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_add_outlined,
                        color: _isInLibrary
                            ? YomuColors.primary
                            : YomuColors.onSurfaceVariant,
                        bg: _isInLibrary
                            ? YomuColors.primary.withOpacity(0.15)
                            : YomuColors.surfaceContainerHigh,
                        onTap: _toggleLibrary,
                      ),
                    ],
                  ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
    width: 110,
    height: 165,
    color: YomuColors.surfaceContainerHigh,
    child: const Icon(
      Icons.image_not_supported_rounded,
      color: YomuColors.outline,
    ),
  );

  Widget _squareBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _pill(String label, {required Color bg, required Color fg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );

  void _startReading() {
    int resumeIdx = _uniqueChapters.length - 1;
    int startPage = 1;

    // Cerca l'indice del capitolo non letto più vecchio (partendo dal fondo della lista)
    final unreadIndex = _uniqueChapters.lastIndexWhere(
      (c) => !_readChapters.contains(c['id']),
    );

    if (unreadIndex != -1) {
      resumeIdx = unreadIndex;
      // Se il capitolo trovato è esattamente quello che avevamo lasciato a metà, ripristina la pagina
      if (_uniqueChapters[unreadIndex]['id'] == _lastReadChapterId) {
        startPage = _lastReadPage;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          mangaId: widget.manga['id'],
          chapters: _uniqueChapters,
          initialIndex: resumeIdx,
          initialPage: startPage,
        ),
      ),
    ).then((_) => _fetchProgress());
  }

  Widget _buildChapterSectionHeader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text(
          'Capitoli',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: YomuColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildChapterTile(int index) {
    if (index == _uniqueChapters.length) {
      return _hasMoreChapters
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: YomuColors.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          : const SizedBox.shrink();
    }

    final chapter = _uniqueChapters[index];
    final chapId = chapter['id'] as String;
    final chapNum = chapter['attributes']['chapter']?.toString() ?? '?';
    final chapTitle = (chapter['attributes']['title'] as String?) ?? '';
    final dateStr = _formatDate(chapter['attributes']['publishAt']);
    final isRead = _readChapters.contains(chapId);
    final savedPage = _chapterPages[chapId];
    final inProgress = savedPage != null && savedPage > 1 && !isRead;
    final isSelected = _selectedChapterIds.contains(chapId);

    return GestureDetector(
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(chapId);
          return;
        }
        final startPage = _chapterPages[chapId] ?? 1;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              mangaId: widget.manga['id'],
              chapters: _uniqueChapters,
              initialIndex: index,
              initialPage: startPage,
            ),
          ),
        ).then((_) => _fetchProgress());
      },
      onLongPress: () => _selectionMode
          ? _toggleSelection(chapId)
          : _showChapterContextMenu(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? YomuColors.primary.withOpacity(0.08)
            : Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: YomuColors.outlineVariant.withOpacity(0.18),
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: _selectionMode
                    ? Padding(
                        key: const ValueKey('cb'),
                        padding: const EdgeInsets.only(right: 12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? YomuColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? YomuColors.primary
                                  : YomuColors.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: YomuColors.onPrimary,
                                )
                              : null,
                        ),
                      )
                    : Container(
                        key: const ValueKey('nb'),
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? YomuColors.surfaceContainerHigh
                              : YomuColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          chapNum,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isRead
                                ? YomuColors.outline
                                : YomuColors.primary,
                          ),
                        ),
                      ),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capitolo $chapNum',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isRead
                            ? YomuColors.outline
                            : YomuColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (inProgress) ...[
                          Text(
                            'Pag. $savedPage',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: YomuColors.primary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: YomuColors.outlineVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (chapTitle.isNotEmpty)
                          Flexible(
                            child: Text(
                              chapTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isRead
                                    ? YomuColors.outlineVariant
                                    : YomuColors.onSurfaceVariant,
                              ),
                            ),
                          )
                        else if (dateStr != null)
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: YomuColors.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!_selectionMode)
                isRead
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: YomuColors.outline,
                        size: 18,
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: YomuColors.outlineVariant,
                        size: 22,
                      ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attrs = widget.manga['attributes'];
    final description = (attrs?['description']?['en'] as String?) ?? '';
    final lastChapter = attrs?['lastChapter']?.toString();
    final status = (attrs?['status']?.toString() ?? 'unknown').toUpperCase();
    final tags =
        (attrs?['tags'] as List?)
            ?.map((t) => (t['attributes']['name']['en'] ?? '') as String)
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    String? author;
    final rels = widget.manga['relationships'] as List?;
    if (rels != null) {
      for (final r in rels) {
        if (r['type'] == 'author') {
          author = r['attributes']?['name']?.toString();
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: YomuColors.surface,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: _selectionMode
            ? YomuColors.surfaceContainerHigh
            : Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _selectionMode
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectionMode
                  ? Icons.close_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          onPressed: _selectionMode
              ? _exitSelectionMode
              : () => Navigator.pop(context),
        ),
        title: _selectionMode
            ? Text(
                '${_selectedChapterIds.length} selezionati',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: YomuColors.onSurface,
                ),
              )
            : null,
        actions: [
          if (!_selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey(_isInLibrary),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isInLibrary
                          ? YomuColors.primary.withOpacity(0.25)
                          : Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isInLibrary
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      color: _isInLibrary ? YomuColors.primary : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                onPressed: _toggleLibrary,
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.select_all_rounded, color: YomuColors.primary),
              tooltip: 'Seleziona tutti',
              onPressed: () => setState(() {
                _selectedChapterIds
                  ..clear()
                  ..addAll(_uniqueChapters.map((c) => c['id'] as String));
              }),
            ),
        ],
      ),

      bottomNavigationBar: _selectionMode ? _buildSelectionBar() : null,

      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeader(description, status, lastChapter, tags, author),
          _buildChapterSectionHeader(),

          if (_isLoadingChapters)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: YomuColors.primary),
                ),
              ),
            )
          else if (_uniqueChapters.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nessun capitolo trovato.',
                  style: TextStyle(color: YomuColors.onSurfaceVariant),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildChapterTile(i),
                childCount:
                    _uniqueChapters.length +
                    (_isLoadingMoreChapters || _hasMoreChapters ? 1 : 0),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
