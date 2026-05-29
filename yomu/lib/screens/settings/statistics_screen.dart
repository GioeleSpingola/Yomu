import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../yomu_colors.dart';
import '../../Lingue/app_localizations.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  int _libraryCount = 0;
  int _chaptersRead = 0;
  int _totalReadingMinutes = 0;

  List<MapEntry<String, int>> _topManga = [];
  List<MapEntry<String, int>> _allMangaWithProgress = [];

  static const Color _goldColor   = Color(0xFFFFD700);
  static const Color _silverColor = Color(0xFFC0C0C0);
  static const Color _bronzeColor = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final libResponse = await Supabase.instance.client
          .from('libreria')
          .select('title, capitoli_letti')
          .eq('user_id', user.id);

      final libList = libResponse as List;
      List<MapEntry<String, int>> mangaStats = [];

      for (var item in libList) {
        final title = item['title']?.toString() ?? 'Sconosciuto';
        final letti = (item['capitoli_letti'] as num?)?.toInt() ?? 0;
        if (letti > 0) mangaStats.add(MapEntry(title, letti));
      }
      mangaStats.sort((a, b) => b.value.compareTo(a.value));

      final progResponse = await Supabase.instance.client
          .from('progressi')
          .select('id')
          .eq('user_id', user.id);
      final histCount = (progResponse as List).length;

      int realMinutes = 0;
      try {
        final statsRow = await Supabase.instance.client
            .from('reading_stats')
            .select('minuti_lettura')
            .eq('user_id', user.id)
            .maybeSingle();
        realMinutes = (statsRow?['minuti_lettura'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _libraryCount = libList.length;
          _chaptersRead = histCount;
          _allMangaWithProgress = mangaStats;
          _topManga = mangaStats.length > 5 ? mangaStats.sublist(0, 5) : mangaStats;
          _totalReadingMinutes = realMinutes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Color> get _extraColors => [YomuColors.primary, YomuColors.secondary];

  Color _colorForRank(int rankIndex) {
    if (rankIndex == 0) return _goldColor;
    if (rankIndex == 1) return _silverColor;
    if (rankIndex == 2) return _bronzeColor;
    return _extraColors[(rankIndex - 3) % _extraColors.length];
  }

  void _showAllManga(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllMangaSheet(
        allManga: _allMangaWithProgress,
        colorForRank: _colorForRank,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final totalMinutes = _totalReadingMinutes;
    final days = totalMinutes ~/ 1440; 
    final hours = (totalMinutes % 1440) ~/ 60;
    final mins = totalMinutes % 60;

    String timeDisplay;
    if (days > 0) {
      timeDisplay = '${days}g ${hours}h ${mins}m';
    } else {
      timeDisplay = '${hours}h ${mins}m';
    }

    return Scaffold(
      backgroundColor: YomuColors.surface,
      appBar: AppBar(
        backgroundColor: YomuColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: YomuColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.translate('settings_stats'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: YomuColors.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: YomuColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        loc.translate('stats_library'),
                        '$_libraryCount',
                        Icons.collections_bookmark_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        loc.translate('stats_chapters'),
                        '$_chaptersRead',
                        Icons.menu_book_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  loc.translate('stats_time'),
                  timeDisplay,
                  Icons.schedule_rounded,
                  isWide: true,
                ),
                if (_topManga.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Text(
                    loc.translate('stats_top_manga'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: YomuColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildPodium(),
                  const SizedBox(height: 20),

                  if (_topManga.length > 3) ...[
                    ..._buildRankRows(startIndex: 3),
                    const SizedBox(height: 20),
                  ],

                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showAllManga(context),
                      icon: Icon(
                        _allMangaWithProgress.length > 5
                            ? Icons.expand_more_rounded
                            : Icons.list_rounded,
                        color: YomuColors.primary,
                      ),
                      label: Text(
                        _allMangaWithProgress.length > 5
                            ? 'Vedi tutti (${_allMangaWithProgress.length})'
                            : 'Vedi lista completa',
                        style: TextStyle(
                          color: YomuColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  Widget _buildPodium() {
    final slots = <int>[];
    if (_topManga.length >= 2) slots.add(1);
    slots.add(0);
    if (_topManga.length >= 3) slots.add(2);

    final blockHeights = {0: 110.0, 1: 80.0, 2: 60.0};
    final rankLabels   = {0: '1°',  1: '2°',  2: '3°'};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: slots.map((rankIndex) {
        final entry  = _topManga[rankIndex];
        final color  = _colorForRank(rankIndex);
        final blockH = blockHeights[rankIndex] ?? 60.0;
        final label  = rankLabels[rankIndex] ?? '';

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.key,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: YomuColors.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: blockH,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.85),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontSize: rankIndex == 0 ? 22 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          'cap.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildRankRows({required int startIndex}) {
    return List.generate(
      (_topManga.length - startIndex).clamp(0, 2),
      (i) {
        final idx   = startIndex + i;
        final entry = _topManga[idx];
        final color = _colorForRank(idx);
        final rank  = '${idx + 1}°';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: YomuColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: color.withOpacity(0.4), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      rank,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: YomuColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value} cap.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon, {
    bool isWide = false,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YomuColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: YomuColors.primary, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isWide ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: YomuColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: YomuColors.onSurfaceVariant,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: YomuColors.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AllMangaSheet extends StatelessWidget {
  final List<MapEntry<String, int>> allManga;
  final Color Function(int) colorForRank;

  const _AllMangaSheet({
    required this.allManga,
    required this.colorForRank,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: YomuColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: YomuColors.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Tutti i manga letti',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: YomuColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: YomuColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${allManga.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: YomuColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: allManga.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = allManga[i];
                    final color = colorForRank(i);
                    final rank  = '${i + 1}°';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: YomuColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: color.withOpacity(0.4), width: 1),
                            ),
                            child: Center(
                              child: Text(
                                rank,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: YomuColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.value} cap.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
