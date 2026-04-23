import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'manga_detail_screen.dart';
import '../yomu_colors.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  User? _user;
  int _filterIndex = 0;
  List<Map<String, dynamic>> _allManga = [];

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() => _user = data.session?.user);
      }
    });
  }

  Widget _buildUnauthenticated() {
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
                const Text(
                  'La tua libreria ti aspetta',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: YomuColors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accedi per salvare i manga e riprendere da dove hai lasciato.',
                  style: TextStyle(
                    fontSize: 14,
                    color: YomuColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: YomuColors.primary,
                    foregroundColor: YomuColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ),
                  child: const Text('Accedi / Registrati'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final labels = ['Tutti', 'In lettura', 'Completati'];
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
              curve: Curves.easeOut,
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
                  color: active
                      ? const Color(0xFF000000)
                      : YomuColors.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMangaCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Sconosciuto';
    final coverUrl = item['cover_url'] ?? '';
    final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
    final chapter = item['chapter'] ?? '';
    final isNew = item['is_new'] == true;
    final updatedAt = item['updated_at'] ?? '';

    return GestureDetector(
      onTap: () {
        final dummyManga = {
          'id': item['manga_id'],
          'attributes': {
            'title': {'en': title},
            'description': {'en': 'Salvato nella tua libreria.'},
          },
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              manga: dummyManga,
              title: title,
              coverUrl: coverUrl,
            ),
          ),
        ).then((_) {
          setState(() {});
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
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
                            Colors.black.withOpacity(0.55),
                          ],
                          stops: const [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: YomuColors.secondary.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  if (chapter.isNotEmpty)
                    Positioned(
                      bottom: 10,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          color: Colors.black.withOpacity(0.45),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            chapter,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      color: Colors.white.withOpacity(0.12),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(color: YomuColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.3,
              color: YomuColors.onSurface,
            ),
          ),
          if (updatedAt.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              updatedAt,
              style: const TextStyle(
                fontSize: 11,
                color: YomuColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return _buildUnauthenticated();

    return Scaffold(
      backgroundColor: YomuColors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: YomuColors.surface.withOpacity(0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: YomuColors.surface.withOpacity(0.75),
            ),
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
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: YomuColors.onSurfaceVariant,
            ),
            onPressed: () {
              showSearch(
                context: context,
                delegate: MangaSearchDelegate(_allManga),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('libreria')
            .stream(primaryKey: ['id'])
            .eq('user_id', _user!.id),
        builder: (context, librarySnapshot) {
          if (librarySnapshot.hasData) {
            _allManga = librarySnapshot.data!;
          }

          // Filtra la libreria in base alla nuova colonna 'status' presente su Supabase
          List<Map<String, dynamic>> savedManga = _allManga.where((item) {
            if (_filterIndex == 0) return true;

            final mId = item['manga_id']?.toString();
            if (mId == null || mId == 'null') return false;

            final status = item['status'] as String?;

            if (_filterIndex == 1) {
              return status == 'reading' || status == null;
            } else if (_filterIndex == 2) {
              return status == 'completed';
            }
            return true;
          }).toList();

          final count = savedManga.length;

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
              SliverToBoxAdapter(child: _buildFilterChips()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$count manga salvati',
                    style: const TextStyle(
                      fontSize: 12,
                      color: YomuColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (librarySnapshot.connectionState == ConnectionState.waiting &&
                  _allManga.isEmpty)
                 SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: YomuColors.primary,
                    ),
                  ),
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
                        const Text(
                          'Nessun manga trovato in questa sezione.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: YomuColors.onSurfaceVariant,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildMangaCard(savedManga[index]),
                      childCount: savedManga.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 24,
                        ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class MangaSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> allManga;

  MangaSearchDelegate(this.allManga);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: YomuColors.surface,
        foregroundColor: YomuColors.onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: YomuColors.onSurfaceVariant),
      ),
      scaffoldBackgroundColor: YomuColors.surface,
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: YomuColors.onSurface, fontSize: 18),
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Cerca nella libreria...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded, color: YomuColors.onSurface),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: YomuColors.onSurface),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final results = allManga.where((manga) {
      final title = (manga['title'] ?? '').toString().toLowerCase();
      return title.contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Nessun risultato',
          style: TextStyle(color: YomuColors.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final title = item['title'] ?? 'Sconosciuto';
        final coverUrl = item['cover_url'] ?? '';

        return ListTile(
          leading: coverUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    coverUrl,
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 40,
                  height: 60,
                  color: YomuColors.surfaceContainerHigh,
                ),
          title: Text(
            title,
            style: const TextStyle(color: YomuColors.onSurface),
          ),
          onTap: () {
            // Logica di reindirizzamento al dettaglio
          },
        );
      },
    );
  }
}
