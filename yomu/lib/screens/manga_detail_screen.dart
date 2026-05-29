import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'auth_screen.dart';
import 'reader_screen.dart';
import 'ai_chat_screen.dart';
import 'main_screen.dart';
import '../yomu_colors.dart';
import '../Lingue/app_localizations.dart';
import 'package:share_plus/share_plus.dart';


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

  bool _isInLibrary = false;
  final Set<String> _readChapters = {};
  String? _lastReadChapterId;
  String _localLibraryStatus = 'reading';
  int _lastReadPage = 1;
  final Map<String, int> _chapterPages = {};
  final Map<String, String> _readDates = {};

  bool _selectionMode = false;
  final Set<String> _selectedChapterIds = {};

  bool _descExpanded = false;

  String _description = '';
  String _status = 'UNKNOWN';
  String? _lastChapter;
  List<String> _tags = [];
  Map<String, String> _tagIdMap = {};
  String? _author;
  bool _renderDescImages = false;
  bool _isFetchingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initMangaData();
    _fetchChapters();
    _checkLibraryStatus();
    _fetchProgress();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _renderDescImages = prefs.getBool('renderDescImages') ?? false;
      });
    }
  }

  void _initMangaData() {
    final attrs = widget.manga['attributes'];
    _description = (attrs?['description']?['en'] as String?) ?? '';
    _status = (attrs?['status']?.toString() ?? 'unknown').toUpperCase();
    _lastChapter = attrs?['lastChapter']?.toString();

    final rawTags = attrs?['tags'] as List? ?? [];
    _tags = rawTags
        .map((t) => (t['attributes']['name']['en'] ?? '') as String)
        .where((s) => s.isNotEmpty)
        .toList();
    _tagIdMap = {};
    for (final t in rawTags) {
      final name = (t['attributes']?['name']?['en'] ?? '') as String;
      final id = (t['id'] ?? '') as String;
      if (name.isNotEmpty && id.isNotEmpty) _tagIdMap[name] = id;
    }

    final rels = widget.manga['relationships'] as List?;
    if (rels != null) {
      for (final r in rels) {
        if (r['type'] == 'author') {
          _author = r['attributes']?['name']?.toString();
          break;
        }
      }
    }

    if (_description.isEmpty) {
      _fetchFullMangaDetails();
    }
  }

  Future<void> _fetchFullMangaDetails() async {
    setState(() => _isFetchingDetails = true);
    try {
      final url = Uri.parse(
        'https://api.mangadex.org/manga/${widget.manga['id']}?includes[]=author',
      );

      final r = await http.get(
        url,
        headers: {
          'User-Agent': 'YomuApp/1.0 (https://github.com/tuo-profilo-github)',
        },
      );

      if (r.statusCode == 200 && mounted) {
        final data = json.decode(r.body)['data'];
        final attrs = data['attributes'];

        setState(() {
          _description = (attrs?['description']?['en'] as String?) ?? '';
          _status = (attrs?['status']?.toString() ?? 'unknown').toUpperCase();
          _lastChapter = attrs?['lastChapter']?.toString();

          _tags =
              (attrs?['tags'] as List?)
                  ?.map((t) => (t['attributes']['name']['en'] ?? '') as String)
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              [];

          final rels = data['relationships'] as List?;
          if (rels != null) {
            for (final rel in rels) {
              if (rel['type'] == 'author') {
                _author = rel['attributes']?['name']?.toString();
                break;
              }
            }
          }
          _isFetchingDetails = false;
        });
      } else {
        if (mounted) setState(() => _isFetchingDetails = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  Future<void> _updateLibraryCounts() async {
    if (!_isInLibrary) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final int capitoliLettiReali = _readChapters.length;
      final int capitoliTotali = _uniqueChapters.length;

      String nuovoStatus = _localLibraryStatus;

      if (capitoliTotali > 0 && capitoliLettiReali >= capitoliTotali) {
        nuovoStatus = 'completed';
      } else if (nuovoStatus == 'completed' &&
          capitoliLettiReali < capitoliTotali) {
        nuovoStatus = 'reading';
      }

      if (mounted && nuovoStatus != _localLibraryStatus) {
        setState(() {
          _localLibraryStatus = nuovoStatus;
        });
      }

      await Supabase.instance.client
          .from('libreria')
          .update({
            'capitoli_letti': capitoliLettiReali,
            'capitoli_totali': capitoliTotali,
            'status': nuovoStatus,
          })
          .eq('user_id', user.id)
          .eq('manga_id', widget.manga['id']);
    } catch (_) {}
  }

  String _getStatusText(BuildContext context, String status) {
    final loc = AppLocalizations.of(context)!;
    switch (status) {
      case 'reading':
        return loc.translate('library_tab_reading');
      case 'plan_to_read':
        return loc.translate('library_tab_planned');
      case 'completed':
        return loc.translate('library_tab_completed');
      case 'on_hold':
        return loc.translate('library_tab_on_hold');
      case 'dropped':
        return loc.translate('library_tab_dropped');
      default:
        return loc.translate('library_tab_reading');
    }
  }

  void _showStatusDialog() {
    final loc = AppLocalizations.of(context)!;
    if (!_isInLibrary) {
      _snack(loc.translate('detail_add_first'));
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
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                loc.translate('detail_your_library'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: YomuColors.onSurface,
                ),
              ),
            ),
            _statusTile(
              loc.translate('library_tab_reading'),
              'reading',
              Icons.menu_book_rounded,
            ),
            _statusTile(
              loc.translate('library_tab_planned'),
              'plan_to_read',
              Icons.schedule_rounded,
            ),
            _statusTile(
              loc.translate('library_tab_completed'),
              'completed',
              Icons.check_circle_rounded,
            ),
            _statusTile(
              loc.translate('library_tab_on_hold'),
              'on_hold',
              Icons.pause_circle_filled_rounded,
            ),
            _statusTile(
              loc.translate('library_tab_dropped'),
              'dropped',
              Icons.cancel_rounded,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(String title, String statusValue, IconData icon) {
    final loc = AppLocalizations.of(context)!;
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
          await Supabase.instance.client
              .from('libreria')
              .update({'status': statusValue})
              .eq('user_id', user.id)
              .eq('manga_id', widget.manga['id'].toString());
          setState(() => _localLibraryStatus = statusValue);
          _snack('${loc.translate('detail_status_updated')} "$title"');
        } catch (_) {
          _snack(loc.translate('detail_update_error'), isError: true);
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
          _readDates.clear();

          if (rows.isNotEmpty) {
            _lastReadChapterId = rows.first['chapter_id'];
            _lastReadPage = rows.first['page'] ?? 1;
          }

          for (var r in rows) {
            if (r['is_read'] == true) {
              _readChapters.add(r['chapter_id']);
              _readDates[r['chapter_id']] = r['last_read'] ?? '';
            }
            _chapterPages[r['chapter_id']] = r['page'] ?? 1;
          }
        });
        if (!_isLoadingChapters) _updateLibraryCounts();
      }
    } catch (_) {}
  }

  // 🌟 FUNZIONE DI REFRESH CORRETTA
  Future<void> _refreshMangaDetails() async {
    // Forziamo il recupero dei capitoli ripartendo da zero
    // _fetchChapters() imposterà in automatico _isLoadingChapters a true!
    await _fetchChapters();
    await _fetchProgress();
    await _checkLibraryStatus();

    // Ricarichiamo anche la descrizione se per caso prima aveva fallito
    if (_description.isEmpty) {
      await _fetchFullMangaDetails();
    }
  }

  Future<void> _fetchChapters() async {
    if (!mounted) return;
    setState(() => _isLoadingChapters = true);

    int localOffset = 0;
    bool hasMore = true;
    List<dynamic> tempUnique = [];
    Set<String> tempSeen = {};

    while (hasMore) {
      final url = Uri.parse(
        'https://api.mangadex.org/manga/${widget.manga['id']}/feed'
        '?translatedLanguage[]=en&order[chapter]=desc'
        '&limit=500&offset=$localOffset',
      );
      try {
        final r = await http.get(url);
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          final list = data['data'] as List;

          for (var ch in list) {
            final ext = ch['attributes']['externalUrl'];
            if (ext != null && ext.toString().isNotEmpty) continue;

            final id = ch['attributes']['chapter'] ?? ch['id'];
            if (tempSeen.add(id)) tempUnique.add(ch);
          }

          if (mounted) {
            setState(() {
              _uniqueChapters.clear();
              _uniqueChapters.addAll(tempUnique);
              if (localOffset == 0) _isLoadingChapters = false;
            });
          }

          if (list.length < 500) {
            hasMore = false;
          } else {
            localOffset += 500;
          }
        } else {
          hasMore = false;
        }
      } catch (_) {
        hasMore = false;
      }
    }

    if (mounted) {
      setState(() => _isLoadingChapters = false);
      _updateLibraryCounts();
    }
  }

  Future<void> _toggleLibrary() async {
    final loc = AppLocalizations.of(context)!;
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
          _snack(loc.translate('detail_removed'));
        }
      } else {
        await Supabase.instance.client.from('libreria').insert({
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'manga_id': widget.manga['id'],
          'title': widget.title,
          'cover_url': widget.coverUrl,
          'status': 'reading',
          'capitoli_totali': _uniqueChapters.length,
          'capitoli_letti': _readChapters.length,
        });
        if (mounted) {
          setState(() {
            _isInLibrary = true;
            _localLibraryStatus = 'reading';
          });
          _snack(loc.translate('detail_added'));
        }
      }
    } catch (e) {
      if (mounted)
        _snack('${loc.translate('common_error')}: $e', isError: true);
    }
  }

  Future<void> _setChapterRead(String chapId, bool read) async {
    await _bulkSetRead([chapId], read);
  }

  Future<void> _bulkSetRead(List<String> ids, bool read) async {
    final loc = AppLocalizations.of(context)!;
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
            .inFilter('chapter_id', subIds);

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
        final futureReadChapters = Set<String>.from(_readChapters);
        if (read) {
          futureReadChapters.addAll(ids);
        } else {
          futureReadChapters.removeAll(ids);
        }

        Map<String, dynamic> libraryUpdates = {};

        if (read) {
          libraryUpdates['last_read'] = DateTime.now()
              .toUtc()
              .toIso8601String();
        }

        if (libraryUpdates.isNotEmpty) {
          await Supabase.instance.client
              .from('libreria')
              .update(libraryUpdates)
              .eq('user_id', user.id)
              .eq('manga_id', widget.manga['id']);
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

            if (_readChapters.isEmpty) {
              _lastReadChapterId = null;
              _lastReadPage = 1;
            }
          }
        });
        _updateLibraryCounts();
        _snack(
          read
              ? '${ids.length} ${loc.translate('detail_marked_read')}'
              : '${ids.length} ${loc.translate('detail_marked_unread')}',
        );
      }
    } catch (e) {
      if (mounted) _snack(loc.translate('detail_save_error'), isError: true);
    }
  }

  Future<void> _markOlderChaptersAsRead(int index, bool read) async {
    final loc = AppLocalizations.of(context)!;
    List<String> targetIds = [];

    for (int i = index + 1; i < _uniqueChapters.length; i++) {
      targetIds.add(_uniqueChapters[i]['id']);
    }

    if (targetIds.isNotEmpty) {
      await _bulkSetRead(targetIds, read);
    } else {
      _snack(loc.translate('detail_no_prev_chapters'));
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
    final loc = AppLocalizations.of(context)!;
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
                    '${loc.translate('detail_chapter')} $chapNum',
                    style: TextStyle(
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
              label: isRead
                  ? loc.translate('detail_mark_unread')
                  : loc.translate('detail_mark_read'),
              color: isRead ? YomuColors.onSurfaceVariant : YomuColors.primary,
              onTap: () {
                Navigator.pop(context);
                _setChapterRead(chapId, !isRead);
              },
            ),
            _ctxTile(
              icon: Icons.checklist_rounded,
              label: loc.translate('detail_mark_prev_read'),
              onTap: () {
                Navigator.pop(context);
                _markOlderChaptersAsRead(index, true);
              },
            ),
            _ctxTile(
              icon: Icons.remove_done_rounded,
              label: loc.translate('detail_mark_prev_unread'),
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
              label: loc.translate('detail_select_all'),
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
              label: loc.translate('detail_select_others'),
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
    Color color = Colors.grey,
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
    final loc = AppLocalizations.of(context)!;
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
                '${sel.length} ${loc.translate('detail_selected')}',
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
                label: loc.translate('detail_read'),
                onTap: () {
                  _bulkSetRead(sel, true);
                  _exitSelectionMode();
                },
              ),
            if (anyRead) ...[
              const SizedBox(width: 8),
              _selBtn(
                icon: Icons.radio_button_unchecked_rounded,
                label: loc.translate('detail_unread'),
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
          style: TextStyle(color: YomuColors.onSurface, fontSize: 13),
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

  Widget _buildDescriptionContent() {
    String plainText = _description.replaceAllMapped(
      RegExp(r'!\[.*?\]\((.*?)\)'),
      (m) => '[Immagine]',
    );
    plainText = plainText.replaceAllMapped(
      RegExp(r'\[img\](.*?)\[\/img\]', caseSensitive: false),
      (m) => '[Immagine]',
    );

    if (!_descExpanded) {
      return Text(
        plainText,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: YomuColors.onSurfaceVariant,
          height: 1.5,
          letterSpacing: 0.1,
        ),
      );
    } else {
      if (!_renderDescImages) {
        return Text(
          plainText,
          style: TextStyle(
            fontSize: 14,
            color: YomuColors.onSurfaceVariant,
            height: 1.5,
            letterSpacing: 0.1,
          ),
        );
      }

      List<Widget> children = [];
      final RegExp imgRegex = RegExp(
        r'!\[.*?\]\((.*?)\)|\[img\](.*?)\[\/img\]',
        caseSensitive: false,
      );
      int lastMatchEnd = 0;

      for (final match in imgRegex.allMatches(_description)) {
        if (match.start > lastMatchEnd) {
          children.add(
            Text(
              _description.substring(lastMatchEnd, match.start).trim(),
              style: TextStyle(
                fontSize: 14,
                color: YomuColors.onSurfaceVariant,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          );
        }

        String? url = match.group(1) ?? match.group(2);
        if (url != null && url.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          );
        }
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < _description.length) {
        children.add(
          Text(
            _description.substring(lastMatchEnd).trim(),
            style: TextStyle(
              fontSize: 14,
              color: YomuColors.onSurfaceVariant,
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
  }

  Widget _buildHeader() {
    final loc = AppLocalizations.of(context)!;
    bool isCaughtUp = false;
    if (_uniqueChapters.isNotEmpty) {
      final readCount = _uniqueChapters
          .where((c) => _readChapters.contains(c['id']))
          .length;
      isCaughtUp = readCount == _uniqueChapters.length;
    }

    bool hasStartedReading =
        _readChapters.isNotEmpty || _lastReadChapterId != null;

    return SliverToBoxAdapter(
      child: Stack(
        children: [
          if (widget.coverUrl.isNotEmpty)
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.4,
                      child: Image.network(widget.coverUrl, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            YomuColors.surface.withOpacity(0.0),
                            YomuColors.surface.withOpacity(0.2),
                            YomuColors.surface.withOpacity(0.7),
                            YomuColors.surface,
                          ],
                          stops: const [0.0, 0.2, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
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
                    GestureDetector(
                      onTap: () {
                        if (widget.coverUrl.isNotEmpty) {
                          final hqUrl = widget.coverUrl
                              .replaceAll('.256.jpg', '')
                              .replaceAll('.512.jpg', '');

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: hqUrl,
                                heroTag: widget.manga['id'] ?? widget.title,
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
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
                                _status,
                                bg: YomuColors.surfaceContainerHighest,
                                fg: YomuColors.onSurfaceVariant,
                              ),
                              if (_lastChapter != null)
                                _pill(
                                  '${loc.translate('history_chapter_short')} $_lastChapter',
                                  bg: YomuColors.primary.withOpacity(0.15),
                                  fg: YomuColors.primary,
                                ),
                            ],
                          ),
                          if (_author != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 13,
                                  color: YomuColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _author!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: YomuColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: _tags
                                  .take(6)
                                  .map(
                                    (t) => GestureDetector(
                                      onTap: () {
                                        final tagId = _tagIdMap[t];
                                        if (tagId == null) return;
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MainScreen(
                                              initialTab: 1,
                                              initialTagId: tagId,
                                              initialTagName: t,
                                            ),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                      child: Container(
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
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: YomuColors.onSurfaceVariant,
                                          ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: YomuColors.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),

                if (_isFetchingDetails)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: YomuColors.primary,
                      ),
                    ),
                  )
                else if (_description.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        alignment: Alignment.topCenter,
                        child: _buildDescriptionContent(),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _descExpanded = !_descExpanded),
                        child: Row(
                          children: [
                            Text(
                              _descExpanded
                                  ? loc.translate('detail_show_less')
                                  : loc.translate('detail_read_more'),
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
                      ),
                    ],
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
                            Text(
                              loc.translate('detail_library_prefix'),
                              style: TextStyle(
                                color: YomuColors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _getStatusText(context, _localLibraryStatus),
                              style: TextStyle(
                                color: YomuColors.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
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
                                onPressed: null,
                                icon: Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  loc.translate('explore_status_completed'),
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
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: _startReading,
                                icon: Icon(Icons.menu_book_rounded, size: 18),
                                label: Text(
                                  hasStartedReading
                                      ? loc.translate('detail_continue_reading')
                                      : loc.translate('detail_start_reading'),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: YomuColors.primary,
                                  foregroundColor: YomuColors.onPrimary,
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: TextStyle(
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
                      const SizedBox(width: 10),
                      _squareBtn(
                        icon: Icons.auto_awesome_rounded,
                        color: YomuColors.primary,
                        bg: YomuColors.primary.withOpacity(0.15),
                        onTap: () {
                          final contextMsg = '${widget.title}${_author != null ? ' di $_author' : ''}';
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (_) => AiChatScreen(currentContext: contextMsg),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(width: 10),
                      _squareBtn(
                        icon: Icons.ios_share_rounded,
                        color: YomuColors.onSurface,
                        bg: YomuColors.surfaceContainerHigh,
                        onTap: () {
                          final String mangaId = widget.manga['id'];
                          // Usiamo un vero link HTTPS che tutti i social riconoscono!
                          final String shareText = 'Dai un\'occhiata a ${widget.title} su Yomu!\n\nhttps://mangadex.org/title/$mangaId';
                          Share.share(shareText);
                        },
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
    child: Icon(Icons.image_not_supported_rounded, color: YomuColors.outline),
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

  Future<void> _startReading() async {
    final loc = AppLocalizations.of(context)!;
    final connectivityResult = await Connectivity().checkConnectivity();
    bool isOffline = false;
    if (connectivityResult is List) {
      isOffline = (connectivityResult as List).contains(ConnectivityResult.none);
    } else {
      isOffline = connectivityResult == ConnectivityResult.none;
    }
    if (isOffline) {
      _snack(loc.translate('detail_offline_unavailable'), isError: true);
      return;
    }

    final bool isWebtoon = _tags.any((t) => t.toLowerCase() == 'long strip' || t.toLowerCase() == 'web comic');

    int targetIndex = -1;
    int targetPage = 1;
    for (int i = _uniqueChapters.length - 1; i >= 0; i--) {
      final chapId = _uniqueChapters[i]['id'];
      if (!_readChapters.contains(chapId)) {
        targetIndex = i;
        targetPage = _chapterPages[chapId] ?? 1;
        break;
      }
    }
    if (targetIndex != -1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            mangaId: widget.manga['id'],
            chapters: _uniqueChapters,
            initialIndex: targetIndex,
            initialPage: targetPage,
            isWebtoon: isWebtoon,
          ),
        ),
      ).then((_) {
        _fetchProgress();
        _checkLibraryStatus();
      });
    } else {
      if (_uniqueChapters.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              mangaId: widget.manga['id'],
              chapters: _uniqueChapters,
              initialIndex: 0,
              initialPage: 1,
              isWebtoon: isWebtoon,
            ),
          ),
        ).then((_) {
          _fetchProgress();
          _checkLibraryStatus();
        });
      } else {
        _snack(loc.translate('detail_no_chapters_start'));
      }
    }
  }

  Widget _buildChapterSectionHeader() {
    final loc = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text(
          loc.translate('detail_chapters_section'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: YomuColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildChapterTile(int index) {
    final loc = AppLocalizations.of(context)!;
    final chapter = _uniqueChapters[index];
    final chapId = chapter['id'] as String;
    final chapNum = chapter['attributes']['chapter']?.toString() ?? '?';
    final chapTitle = (chapter['attributes']['title'] as String?) ?? '';

    final rawDate = chapter['attributes']['publishAt'];
    DateTime? chapDate;
    if (rawDate != null) {
      chapDate = DateTime.parse(rawDate as String).toLocal();
    }

    final isRead = _readChapters.contains(chapId);
    String? readDateRaw = _readDates[chapId];
    String displayDate = "";

    if (isRead && readDateRaw != null && readDateRaw.isNotEmpty) {
      String fixedIso = readDateRaw;
      if (!fixedIso.endsWith('Z') && !fixedIso.contains('+')) {
        fixedIso += 'Z';
      }
      try {
        DateTime dt = DateTime.parse(fixedIso).toLocal();
        displayDate =
            '${loc.translate('detail_read_on')} ${dt.day}/${dt.month}';
      } catch (_) {
        displayDate = loc.translate('detail_read_recently');
      }
    } else if (chapDate != null) {
      displayDate = '${chapDate.day}/${chapDate.month}/${chapDate.year}';
    }

    final savedPage = _chapterPages[chapId];
    final inProgress = savedPage != null && savedPage > 1 && !isRead;
    final isSelected = _selectedChapterIds.contains(chapId);

    return GestureDetector(
      onTap: () async {
        if (_selectionMode) {
          _toggleSelection(chapId);
          return;
        }
        final connectivityResult = await Connectivity().checkConnectivity();
        bool isOffline = false;
        if (connectivityResult is List) {
          isOffline = (connectivityResult as List).contains(ConnectivityResult.none);
        } else {
          isOffline = connectivityResult == ConnectivityResult.none;
        }
        if (isOffline) {
          _snack(loc.translate('detail_offline_unavailable'), isError: true);
          return;
        }
        
        final bool isWebtoon = _tags.any((t) => t.toLowerCase() == 'long strip' || t.toLowerCase() == 'web comic');
        final startPage = _chapterPages[chapId] ?? 1;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              mangaId: widget.manga['id'],
              chapters: _uniqueChapters,
              initialIndex: index,
              initialPage: startPage,
              isWebtoon: isWebtoon,
            ),
          ),
        ).then((_) {
          _fetchProgress();
          _checkLibraryStatus();
        });
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
                    Row(
                      children: [
                        Text(
                          '${loc.translate('detail_chapter')} $chapNum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isRead
                                ? YomuColors.outline
                                : YomuColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (inProgress) ...[
                          Text(
                            '${loc.translate('history_page_short')} $savedPage',
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
                            decoration: BoxDecoration(
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
                        else if (displayDate.isNotEmpty)
                          Text(
                            displayDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: isRead
                                  ? YomuColors.primary.withOpacity(0.8)
                                  : YomuColors.outlineVariant,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_selectionMode)
                isRead
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: YomuColors.outline,
                        size: 18,
                      )
                    : Icon(
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
    final loc = AppLocalizations.of(context)!;
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
                '${_selectedChapterIds.length} ${loc.translate('detail_selected')}',
                style: TextStyle(
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
              tooltip: loc.translate('detail_select_all'),
              onPressed: () => setState(() {
                _selectedChapterIds
                  ..clear()
                  ..addAll(_uniqueChapters.map((c) => c['id'] as String));
              }),
            ),
        ],
      ),
      bottomNavigationBar: _selectionMode ? _buildSelectionBar() : null,

      // 🌟 IL REFRESH INDICATOR CON L'OFFSET
      body: RefreshIndicator(
        color: YomuColors.primary,
        backgroundColor: YomuColors.surfaceContainerHigh,
        edgeOffset: 90.0, // Spinge la rotella sotto l'header trasparente scuro!
        onRefresh: _refreshMangaDetails,
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Per poter tirare sempre giù
          slivers: [
            _buildHeader(),
            _buildChapterSectionHeader(),
            if (_isLoadingChapters)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: YomuColors.primary),
                  ),
                ),
              )
            else if (_uniqueChapters.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    loc.translate('detail_no_chapters'),
                    style: TextStyle(color: YomuColors.onSurfaceVariant),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildChapterTile(i),
                  childCount: _uniqueChapters.length,
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final Object heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: InteractiveViewer(
        panEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Hero(
            tag: heroTag,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
