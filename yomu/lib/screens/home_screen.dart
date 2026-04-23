import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manga_detail_screen.dart';
import '../yomu_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<dynamic> _mangaList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
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

  final Map<String, String> _statusOptions = {
    'In corso': 'ongoing',
    'Completato': 'completed',
    'Pausa': 'hiatus',
    'Cancellato': 'cancelled',
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
    _fetchTags();
    _fetchManga();
    _initLibraryListener();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 500 &&
          !_isLoadingMore) {
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

  Future<void> _fetchTags() async {
    try {
      final r = await http.get(Uri.parse('https://api.mangadex.org/manga/tag'));
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
    return 'https://api.mangadex.org/manga?includes[]=cover_art'
        '&limit=$_limit&offset=$_offset'
        '&hasAvailableChapters=true'
        '&contentRating[]=safe&contentRating[]=suggestive'
        '$search$tags$status$demog';
  }

  Future<void> _fetchManga() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse(_buildUrl()));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (mounted) {
          setState(() {
            _mangaList.addAll(data['data']);
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreManga() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _offset += _limit;
    try {
      final r = await http.get(Uri.parse(_buildUrl()));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (mounted) {
          setState(() {
            _mangaList.addAll(data['data']);
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
        if (fn.isNotEmpty) return 'https://uploads.mangadex.org/covers/$id/$fn';
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

  void _showFilterSheet() {
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
                          const Text(
                            'Filtri',
                            style: TextStyle(
                              fontFamily: 'Manrope',
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
                                '$_activeFilterCount attivi',
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
                              child: const Text(
                                'Resetta',
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
                      label: 'Stato',
                      icon: Icons.signal_cellular_alt_rounded,
                      child: _segmentedOptions(
                        options: _statusOptions,
                        selected: _selectedStatus,
                        onToggle: (v) => setModal(() {
                          _selectedStatus.contains(v)
                              ? _selectedStatus.remove(v)
                              : _selectedStatus.add(v);
                        }),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _filterSection(
                      label: 'Target',
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
                      label: 'Generi e temi',
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
                      textStyle: const TextStyle(
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
                        const Text('Applica filtri'),
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
                              style: const TextStyle(
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
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: YomuColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: YomuColors.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cerca manga, autori o generi…',
          hintStyle: const TextStyle(
            color: YomuColors.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: YomuColors.onSurfaceVariant,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isNotEmpty
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: YomuColors.surfaceContainerHigh,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: YomuColors.outline,
                            ),
                          ),
                        )
                      : Container(
                          color: YomuColors.surfaceContainerHigh,
                          child: const Icon(
                            Icons.image_not_supported_rounded,
                            color: YomuColors.outline,
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
                            Colors.black.withOpacity(0.6),
                          ],
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
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Colors.amber,
                          size: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: YomuColors.onSurface,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _mangaList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: YomuColors.primary),
        ),
      );
    }
    if (_mangaList.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'Nessun manga trovato.',
            style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 15),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((_, i) {
          if (i >= _mangaList.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: YomuColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return _buildBrowseCard(_mangaList[i]);
        }, childCount: _mangaList.length + (_isLoadingMore ? 2 : 0)),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 10,
          mainAxisSpacing: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YomuColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAiChatModal,
        backgroundColor: YomuColors.primary,
        foregroundColor: YomuColors
            .onPrimary, // L'icona e il testo saranno neri/viola scuro sul bottone chiaro
        elevation: 4,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text(
          'Consigli AI',
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
                      final label = _statusOptions.entries
                          .firstWhere((e) => e.value == v)
                          .key;
                      return _activePill(
                        label,
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
                      final name = tag?['attributes']?['name']?['en'] ?? id;
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
                            '+${_selectedTags.length - 3} generi',
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
                  const Text(
                    'Ultimi aggiornamenti',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: YomuColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    Text(
                      'Filtrati',
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
        ],
      ),
    );
  }

  // ─── AI Chatbot Mockup ───────────────────────────────────────────────────
  void _showAiChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: YomuColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Trattino in alto
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: YomuColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Icona AI Scintillante
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: YomuColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 36,
                  color: YomuColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Yomu AI',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: YomuColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Analizzo la tua libreria e i tuoi progressi per consigliarti la tua prossima ossessione. Cosa ti va di leggere oggi?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: YomuColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              // Finta barra di chat per il mockup
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: YomuColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: YomuColors.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chiedi a Yomu AI...',
                        style: TextStyle(
                          color: YomuColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.send_rounded,
                      color: YomuColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
