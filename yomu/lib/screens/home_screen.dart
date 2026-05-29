import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manga_detail_screen.dart';
import '../yomu_colors.dart';
import 'ai_chat_screen.dart';
import '../Lingue/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  final String? initialTagId;
  final String? initialTagName;

  const HomeScreen({
    super.key,
    this.initialTagId,
    this.initialTagName,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<dynamic> _mangaList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreManga = true;
  int _offset = 0;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Set<String> _savedMangaIds = {};
  RealtimeChannel? _libSubscription;

  List<dynamic> _availableTags = [];
  Set<String> _selectedTags = {};
  Set<String> _selectedStatus = {};
  Set<String> _selectedDemographics = {};
  String _selectedSort = 'followedCount';

  String _displayMode = 'compact';
  int _gridColumns = 3;
  bool _autoGrid = true;

  // 👇 Variabili per il risparmio dati aggiunte
  String _imageQuality = 'Alta';
  bool _dataSaver = false;

  final Map<String, String> _sortKeys = {
    'explore_sort_popular': 'followedCount',
    'explore_sort_rating': 'rating',
    'explore_sort_latest': 'latestUploadedChapter',
    'explore_sort_alpha': 'title',
  };

  final Map<String, String> _statusKeys = {
    'explore_status_ongoing': 'ongoing',
    'explore_status_completed': 'completed',
    'explore_status_hiatus': 'hiatus',
    'explore_status_cancelled': 'cancelled',
  };

  final Map<String, String> _demographicOptions = {
    'Shounen': 'shounen',
    'Shoujo': 'shoujo',
    'Seinen': 'seinen',
    'Josei': 'josei',
  };

  @override
  void initState() {
    super.initState();
    _loadDisplaySettings();
    _fetchTags().then((_) {
      if (widget.initialTagId != null) {
        setState(() => _selectedTags.add(widget.initialTagId!));
        _applyFilters();
      }
    });
    _fetchManga();
    _initLibraryListener();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 500 &&
          !_isLoadingMore &&
          _hasMoreManga) {
        _fetchMoreManga();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    if (_libSubscription != null) {
      Supabase.instance.client.removeChannel(_libSubscription!);
    }
    super.dispose();
  }

  Future<void> _loadDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _displayMode = prefs.getString('displayMode') ?? 'compact';
        _gridColumns = prefs.getInt('gridColumns') ?? 3;
        _autoGrid = prefs.getBool('autoGrid') ?? true;
        // 👇 Carichiamo le impostazioni di qualità
        _imageQuality = prefs.getString('imageQuality') ?? 'Alta';
        _dataSaver = prefs.getBool('dataSaver') ?? false;
      });
    }
  }

  Future<void> _saveDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayMode', _displayMode);
    await prefs.setInt('gridColumns', _gridColumns);
    await prefs.setBool('autoGrid', _autoGrid);
  }

  Future<void> _fetchTags() async {
    try {
      // 🌟 FIX: Rimosso corsproxy.io, ora l'app parla direttamente col server!
      final r = await http.get(
        Uri.parse('https://api.mangadex.org/manga/tag'),
      );
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (mounted) {
          setState(() {
            _availableTags = (data['data'] as List)
                .where(
                  (t) =>
                      t['attributes']['group'] == 'genre' ||
                      t['attributes']['group'] == 'theme',
                )
                .toList();
          });
        }
      }
    } catch (_) {}
  }
  void _initLibraryListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _savedMangaIds = {});
      return;
    }
    _loadInitialLibrary();
    _libSubscription = Supabase.instance.client
        .channel('public:libreria')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'libreria',
          callback: (_) => _loadInitialLibrary(),
        )
        .subscribe();
  }

  Future<void> _loadInitialLibrary() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('libreria')
          .select('manga_id')
          .eq('user_id', user.id);
      if (mounted) {
        setState(() {
          _savedMangaIds = (data as List)
              .map((e) => e['manga_id'].toString())
              .toSet();
        });
      }
    } catch (_) {}
  }

  String _buildUrl() {
    final search = _searchQuery.isNotEmpty
        ? '&title=${Uri.encodeComponent(_searchQuery)}'
        : '';
    final tags = _selectedTags.map((id) => '&includedTags[]=$id').join();
    final status = _selectedStatus.map((s) => '&status[]=$s').join();
    final demog = _selectedDemographics
        .map((d) => '&publicationDemographic[]=$d')
        .join();

    // 🌟 FIX: Rimosso corsproxy.io dall'URL base!
    return 'https://api.mangadex.org/manga?includes[]=cover_art'
        '&limit=$_limit&offset=$_offset'
        '&hasAvailableChapters=true'
        '&contentRating[]=safe'
        '&order[$_selectedSort]=desc'
        '$search$tags$status$demog';
  }

  Future<void> _fetchManga() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasMoreManga = true;
    });
    try {
      // 🌟 AGGIUNTA FONDAMENTALE: Gli Headers
      final r = await http.get(
        Uri.parse(_buildUrl()),
        headers: {
          'User-Agent': 'YomuApp/1.0 (https://github.com/tuo-profilo-github)'
        },
      );
      
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final items = data['data'] as List;
        if (mounted) {
          setState(() {
            _mangaList.addAll(items);
            _hasMoreManga = items.length == _limit;
            _isLoading = false;
          });
        }
      } else {
        print("💥 ERRORE API: Server MangaDex ha risposto con ${r.statusCode}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("💥 ERRORE DI CONNESSIONE: $e");
    }
  }

  Future<void> _fetchMoreManga() async {
    if (_isLoadingMore || !_hasMoreManga) return;
    setState(() => _isLoadingMore = true);
    _offset += _limit;
    try {
      final r = await http.get(Uri.parse(_buildUrl()));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final items = data['data'] as List;
        if (mounted) {
          setState(() {
            _mangaList.addAll(items);
            _hasMoreManga = items.length == _limit;
            _isLoadingMore = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
      _offset = 0;
      _mangaList.clear();
    });
    _fetchManga();
  }

  void _applyFilters() {
    setState(() {
      _offset = 0;
      _mangaList.clear();
    });
    _fetchManga();
  }

  String _coverUrl(dynamic manga) {
    final id = manga['id']?.toString() ?? '';
    for (var rel in (manga['relationships'] as List? ?? [])) {
      if (rel['type'] == 'cover_art') {
        final fn = rel['attributes']?['fileName'] ?? '';
        if (fn.isNotEmpty) {
          // 👇 LA MAGIA DEL RISPARMIO DATI 👇
          String suffix = '';
          if (_dataSaver || _imageQuality == 'Bassa') {
            suffix = '.256.jpg'; // Super compresso, carica in un millisecondo
          } else if (_imageQuality == 'Media') {
            suffix = '.512.jpg'; // Qualità bilanciata
          }
          return 'https://uploads.mangadex.org/covers/$id/$fn$suffix';
        }
      }
    }
    return '';
  }

  String _title(dynamic manga) {
    final attrs = manga['attributes']['title'] as Map;
    return (attrs['en'] ?? attrs.values.firstOrNull ?? 'Sconosciuto')
        .toString();
  }

  bool get _hasActiveFilters =>
      _selectedTags.isNotEmpty ||
      _selectedStatus.isNotEmpty ||
      _selectedDemographics.isNotEmpty;

  int get _activeFilterCount =>
      _selectedTags.length +
      _selectedStatus.length +
      _selectedDemographics.length;

  void _showDisplaySettingsSheet() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: YomuColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
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
                            valueIndicatorColor: YomuColors.primary,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '2',
                                style: TextStyle(
                                  color: YomuColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '6',
                                style: TextStyle(
                                  color: YomuColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
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

  void _showFilterSheet() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: YomuColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: YomuColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            loc.translate('explore_filters'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: YomuColors.onSurface,
                            ),
                          ),
                          if (_hasActiveFilters) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: YomuColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_activeFilterCount ${loc.translate('explore_active')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: YomuColors.primary,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setModal(() {
                              _selectedTags.clear();
                              _selectedStatus.clear();
                              _selectedDemographics.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: YomuColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                loc.translate('common_reset'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: YomuColors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      color: YomuColors.outlineVariant.withOpacity(0.2),
                      height: 1,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _filterSection(
                      label: loc.translate('explore_sort_by'),
                      icon: Icons.sort_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sortKeys.entries.map((e) {
                          final isSel = _selectedSort == e.value;
                          return GestureDetector(
                            onTap: () =>
                                setModal(() => _selectedSort = e.value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? YomuColors.primary
                                    : YomuColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel
                                      ? YomuColors.primary
                                      : YomuColors.outlineVariant.withOpacity(
                                          0.4,
                                        ),
                                ),
                              ),
                              child: Text(
                                loc.translate(e.key),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? YomuColors.onPrimary
                                      : YomuColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _filterSection(
                      label: loc.translate('explore_demographic'),
                      icon: Icons.people_rounded,
                      child: _segmentedOptions(
                        options: _demographicOptions,
                        selected: _selectedDemographics,
                        onToggle: (v) => setModal(() {
                          _selectedDemographics.contains(v)
                              ? _selectedDemographics.remove(v)
                              : _selectedDemographics.add(v);
                        }),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _filterSection(
                      label: loc.translate('explore_genres'),
                      icon: Icons.label_rounded,
                      child: _availableTags.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  color: YomuColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 7,
                              runSpacing: 8,
                              children: _availableTags.map((tag) {
                                final id = tag['id'] as String;
                                final name =
                                    tag['attributes']['name']['en']
                                        ?.toString() ??
                                    '?';
                                final sel = _selectedTags.contains(id);
                                return _tagChip(
                                  label: name,
                                  selected: sel,
                                  onTap: () => setModal(
                                    () => sel
                                        ? _selectedTags.remove(id)
                                        : _selectedTags.add(id),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Container(
                color: YomuColors.surfaceContainer,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: YomuColors.primary,
                      foregroundColor: YomuColors.onPrimary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _applyFilters();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(loc.translate('explore_apply_filters')),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: YomuColors.onPrimary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: YomuColors.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterSection({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: YomuColors.primary),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: YomuColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _segmentedOptions({
    required Map<String, String> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final isSel = selected.contains(e.value);
        return GestureDetector(
          onTap: () => onToggle(e.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel
                  ? YomuColors.primary
                  : YomuColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel
                    ? YomuColors.primary
                    : YomuColors.outlineVariant.withOpacity(0.4),
              ),
            ),
            child: Text(
              e.key,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSel
                    ? YomuColors.onPrimary
                    : YomuColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _tagChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? YomuColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? YomuColors.primary.withOpacity(0.6)
                : YomuColors.outlineVariant.withOpacity(0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 12, color: YomuColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? YomuColors.primary
                    : YomuColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final loc = AppLocalizations.of(context)!;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: YomuColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: YomuColors.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: loc.translate('explore_search_hint'),
          hintStyle: TextStyle(
            color: YomuColors.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: YomuColors.onSurfaceVariant,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: YomuColors.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    _performSearch('');
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _showDisplaySettingsSheet,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.display_settings_rounded,
                      color: YomuColors.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _showFilterSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? YomuColors.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _hasActiveFilters
                          ? Border.all(
                              color: YomuColors.primary.withOpacity(0.4),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: _hasActiveFilters
                              ? YomuColors.primary
                              : YomuColors.onSurfaceVariant,
                          size: 18,
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$_activeFilterCount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: YomuColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onSubmitted: _performSearch,
      ),
    );
  }

  Widget _buildBrowseCard(dynamic manga) {
    final id = manga['id']?.toString() ?? '';
    final isSaved = id.isNotEmpty && _savedMangaIds.contains(id);
    final url = _coverUrl(manga);
    final name = _title(manga);

    Widget cardContent;

    if (_displayMode == 'list') {
      cardContent = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 85,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isNotEmpty
                      ? CachedNetworkImage(
  imageUrl: url, // ⚠️ Usa 'coverUrl' se sei nel file library_screen.dart
  fit: BoxFit.cover,
  fadeInDuration: const Duration(milliseconds: 200),
  placeholder: (context, url) => Container(color: YomuColors.surfaceContainerHigh),
  errorWidget: (context, url, error) => Container(color: YomuColors.surfaceContainerHigh),
)
                      : Container(color: YomuColors.surfaceContainerHigh),
                  if (isSaved)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Icon(
                        Icons.bookmark_rounded,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: YomuColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_displayMode == 'comfortable') {
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isNotEmpty
                      ? CachedNetworkImage(
  imageUrl: url, // ⚠️ Usa 'coverUrl' se sei nel file library_screen.dart
  fit: BoxFit.cover,
  fadeInDuration: const Duration(milliseconds: 200),
  placeholder: (context, url) => Container(color: YomuColors.surfaceContainerHigh),
  errorWidget: (context, url, error) => Container(color: YomuColors.surfaceContainerHigh),
)
                      : Container(color: YomuColors.surfaceContainerHigh),
                  if (isSaved)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: YomuColors.primary.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.bookmark_rounded,
                          color: Colors.amber,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: Text(
              name,
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
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isNotEmpty
                ? CachedNetworkImage(
  imageUrl: url, // ⚠️ Usa 'coverUrl' se sei nel file library_screen.dart
  fit: BoxFit.cover,
  fadeInDuration: const Duration(milliseconds: 200),
  placeholder: (context, url) => Container(color: YomuColors.surfaceContainerHigh),
  errorWidget: (context, url, error) => Container(color: YomuColors.surfaceContainerHigh),
)
                : Container(color: YomuColors.surfaceContainerHigh),
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
            if (isSaved)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: YomuColors.primary.withOpacity(0.85),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Icon(
                    Icons.bookmark_rounded,
                    color: Colors.amber,
                    size: 13,
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                name,
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
      onTap: () =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MangaDetailScreen(manga: manga, title: name, coverUrl: url),
            ),
          ).then((_) {
            _loadInitialLibrary();
            setState(() {});
          }),
      child: cardContent,
    );
  }

  Widget _buildBody() {
    final loc = AppLocalizations.of(context)!;
    if (_isLoading && _mangaList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: YomuColors.primary),
        ),
      );
    }
    if (_mangaList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            loc.translate('explore_not_found'),
            style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 15),
          ),
        ),
      );
    }

    if (_displayMode == 'list') {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBrowseCard(_mangaList[i]),
            ),
            childCount: _mangaList.length,
          ),
        ),
      );
    }

    int actualColumns = _autoGrid
        ? (MediaQuery.of(context).size.width ~/ 110).clamp(2, 6)
        : _gridColumns;

    double ratio = _displayMode == 'comfortable' ? 0.52 : 0.65;

    if (actualColumns == 2) ratio += 0.15;
    if (actualColumns >= 4) ratio -= (0.05 * (actualColumns - 3));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((_, i) {
          return _buildBrowseCard(_mangaList[i]);
        }, childCount: _mangaList.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: actualColumns,
          childAspectRatio: ratio,
          crossAxisSpacing: 10,
          mainAxisSpacing: _displayMode == 'comfortable' ? 18 : 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: YomuColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiChatScreen()),
          );
        },
        backgroundColor: YomuColors.primary,
        foregroundColor: YomuColors.onPrimary,
        elevation: 4,
        icon: Icon(Icons.auto_awesome_rounded),
        label: Text(
          loc.translate('chat_ai_recs'),
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: YomuColors.surface.withOpacity(0.85),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 0,
            toolbarHeight: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: Container(
                color: YomuColors.surface.withOpacity(0.85),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _buildSearchBar(),
              ),
            ),
          ),
          if (_hasActiveFilters)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  children: [
                    ..._selectedStatus.map((v) {
                      final key = _statusKeys.entries
                          .firstWhere((e) => e.value == v)
                          .key;
                      return _activePill(
                        loc.translate(key),
                        onRemove: () => setState(() {
                          _selectedStatus.remove(v);
                          _applyFilters();
                        }),
                      );
                    }),
                    ..._selectedDemographics.map((v) {
                      final label = _demographicOptions.entries
                          .firstWhere((e) => e.value == v)
                          .key;
                      return _activePill(
                        label,
                        onRemove: () => setState(() {
                          _selectedDemographics.remove(v);
                          _applyFilters();
                        }),
                      );
                    }),
                    ..._selectedTags.take(3).map((id) {
                      final tag = _availableTags.firstWhere(
                        (t) => t['id'] == id,
                        orElse: () => null,
                      );
                      
                      String name = tag?['attributes']?['name']?['en'] ?? id;
                      if (tag == null && id == widget.initialTagId && widget.initialTagName != null) {
                        name = widget.initialTagName!;
                      }
                      
                      return _activePill(
                        name,
                        onRemove: () => setState(() {
                          _selectedTags.remove(id);
                          _applyFilters();
                        }),
                      );
                    }),
                    if (_selectedTags.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Center(
                          child: Text(
                            '+${_selectedTags.length - 3} ${loc.translate('explore_more_genres')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: YomuColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Text(
                    loc.translate(
                      _sortKeys.entries
                          .firstWhere((e) => e.value == _selectedSort)
                          .key,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: YomuColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    Text(
                      loc.translate('explore_filtered'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: YomuColors.primary.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildBody(),
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80, top: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: YomuColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _activePill(String label, {required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
      decoration: BoxDecoration(
        color: YomuColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: YomuColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: YomuColors.primary,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: YomuColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
