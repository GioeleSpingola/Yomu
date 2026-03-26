import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ugpvxhsuxspeglueotvr.supabase.co',
    anonKey: 'sb_publishable_135VW_z4BzrYDsbQS-QVTQ_wYiXnm1_',
  );
  runApp(const YomuApp());
}

class YomuApp extends StatelessWidget {
  const YomuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yomu Manga Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [const HomeScreen(), const LibraryScreen()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Abbiamo rimosso l'AppBar globale. Ora ogni schermata gestisce la sua.
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Esplora'),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark),
            label: 'Libreria',
          ),
        ],
      ),
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // La libreria ora ha il suo Scaffold con il suo titolo
    return Scaffold(
      appBar: AppBar(title: const Text('La mia Libreria'), elevation: 2),
      body: const Center(
        child: Text('Libreria vuota (per ora)', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

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

  // Variabili per la ricerca
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchManga();

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchManga() async {
    setState(() {
      _isLoading = true;
    });

    // Se c'è un testo di ricerca, lo aggiungiamo all'URL
    final searchParam = _searchQuery.isNotEmpty
        ? '&title=${Uri.encodeComponent(_searchQuery)}'
        : '';
    final url = Uri.parse(
      'https://api.mangadex.org/manga?includes[]=cover_art&limit=$_limit&offset=$_offset&hasAvailableChapters=true$searchParam',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _mangaList.addAll(data['data']);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMoreManga() async {
    setState(() {
      _isLoadingMore = true;
    });
    _offset += _limit;

    final searchParam = _searchQuery.isNotEmpty
        ? '&title=${Uri.encodeComponent(_searchQuery)}'
        : '';
    final url = Uri.parse(
      'https://api.mangadex.org/manga?includes[]=cover_art&limit=$_limit&offset=$_offset&hasAvailableChapters=true$searchParam',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _mangaList.addAll(data['data']);
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
      _offset = 0; // Resetta la pagina a 0
      _mangaList.clear(); // Pulisce i vecchi risultati
    });
    _fetchManga(); // Lancia la nuova ricerca
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: TextField(
          controller: _searchController,
          textInputAction:
              TextInputAction.search, // Cambia il tasto invio in "Cerca"
          decoration: InputDecoration(
            hintText: 'Cerca un manga...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            // Mostra la "X" per cancellare solo se c'è del testo scritto
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch(''); // Resetta la ricerca
                    },
                  )
                : null,
          ),
          onSubmitted: _performSearch,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _mangaList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mangaList.isEmpty) {
      return const Center(
        child: Text('Nessun manga trovato. Prova un altro titolo!'),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _mangaList.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _mangaList.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final manga = _mangaList[index];
        final title =
            manga['attributes']['title']['en'] ??
            manga['attributes']['title'].values.first ??
            'Titolo Sconosciuto';

        String coverFileName = '';
        if (manga['relationships'] != null) {
          for (var rel in manga['relationships']) {
            if (rel['type'] == 'cover_art') {
              coverFileName = rel['attributes']['fileName'] ?? '';
              break;
            }
          }
        }

        final coverUrl = coverFileName.isNotEmpty
            ? 'https://uploads.mangadex.org/covers/${manga['id']}/$coverFileName'
            : '';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaDetailScreen(
                  manga: manga,
                  title: title,
                  coverUrl: coverUrl,
                ),
              ),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.image_not_supported, size: 40),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// SOTTO QUESTA RIGA IL CODICE È IDENTICO A PRIMA (Dettagli e Lettore)
// ----------------------------------------------------------------------

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

  @override
  void initState() {
    super.initState();
    _fetchChapters();

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

  Future<void> _fetchChapters() async {
    final url = Uri.parse(
      'https://api.mangadex.org/manga/${widget.manga['id']}/feed?translatedLanguage[]=en&order[chapter]=desc&limit=$_limit&offset=$_offset',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newChapters = data['data'];

        for (var chapter in newChapters) {
          final chapNum = chapter['attributes']['chapter'];
          final identifier = chapNum ?? chapter['id'];

          if (!_seenChapters.contains(identifier)) {
            _seenChapters.add(identifier);
            _uniqueChapters.add(chapter);
          }
        }

        if (mounted) {
          setState(() {
            _isLoadingChapters = false;
            if (newChapters.length < _limit) {
              _hasMoreChapters = false;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  Future<void> _fetchMoreChapters() async {
    setState(() {
      _isLoadingMoreChapters = true;
    });
    _offset += _limit;

    final url = Uri.parse(
      'https://api.mangadex.org/manga/${widget.manga['id']}/feed?translatedLanguage[]=en&order[chapter]=desc&limit=$_limit&offset=$_offset',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newChapters = data['data'];

        for (var chapter in newChapters) {
          final chapNum = chapter['attributes']['chapter'];
          final identifier = chapNum ?? chapter['id'];

          if (!_seenChapters.contains(identifier)) {
            _seenChapters.add(identifier);
            _uniqueChapters.add(chapter);
          }
        }

        if (mounted) {
          setState(() {
            _isLoadingMoreChapters = false;
            if (newChapters.length < _limit) {
              _hasMoreChapters = false;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreChapters = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final description =
        widget.manga['attributes']['description']['en'] ??
        'Nessuna descrizione disponibile.';

    final lastChapter = widget.manga['attributes']['lastChapter'];
    final status =
        widget.manga['attributes']['status']?.toString().toUpperCase() ??
        'SCONOSCIUTO';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.coverUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.coverUrl,
                        width: 120,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 120),
                      ),
                    )
                  else
                    const Icon(Icons.image_not_supported, size: 120),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                status,
                                style: const TextStyle(fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            if (lastChapter != null)
                              Chip(
                                label: Text(
                                  'Cap. $lastChapter',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.deepPurple.withOpacity(
                                  0.3,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 130),
                          child: SingleChildScrollView(
                            child: Text(
                              description,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Capitoli (EN)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_isLoadingChapters)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_uniqueChapters.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nessun capitolo trovato.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _uniqueChapters.length) {
                    return _hasMoreChapters
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const SizedBox.shrink();
                  }

                  final chapter = _uniqueChapters[index];
                  final chapNum = chapter['attributes']['chapter'] ?? '?';
                  final chapTitle = chapter['attributes']['title'] ?? '';

                  return ListTile(
                    title: Text('Capitolo $chapNum'),
                    subtitle: chapTitle.isNotEmpty
                        ? Text(
                            chapTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: const Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReaderScreen(
                            chapterId: chapter['id'],
                            chapterTitle: 'Cap. $chapNum',
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount:
                    _uniqueChapters.length +
                    (_isLoadingMoreChapters || _hasMoreChapters ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }
}

enum ReadingMode { leftToRight, rightToLeft, vertical }

class ReaderScreen extends StatefulWidget {
  final String chapterId;
  final String chapterTitle;

  const ReaderScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<String> _imageUrls = [];
  bool _isLoading = true;

  bool _showUi = true;
  int _currentPage = 1;
  late PageController _pageController;

  ReadingMode _readingMode =
      ReadingMode.rightToLeft; // Default impostato per i manga
  bool _tapToTurnEnabled = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPages() async {
    final url = Uri.parse(
      'https://api.mangadex.org/at-home/server/${widget.chapterId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final baseUrl = data['baseUrl'];
        final chapterHash = data['chapter']['hash'];
        final List<dynamic> filenames = data['chapter']['data'];

        final List<String> urls = filenames.map((filename) {
          return '$baseUrl/data/$chapterHash/$filename';
        }).toList();

        if (mounted) {
          setState(() {
            _imageUrls = urls;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  void _goToNextPage() {
    if (_currentPage < _imageUrls.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Impostazioni Lettura',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Cambio pagina al tocco',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Tocca i bordi dello schermo per cambiare pagina',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: _tapToTurnEnabled,
                    activeColor: Colors.deepPurpleAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() => _tapToTurnEnabled = value);
                      setModalState(() => _tapToTurnEnabled = value);
                    },
                  ),
                  const Divider(color: Colors.grey),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Direzione di Lettura',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioListTile<ReadingMode>(
                    title: const Text(
                      'Da Destra a Sinistra (Manga)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: ReadingMode.rightToLeft,
                    groupValue: _readingMode,
                    activeColor: Colors.deepPurpleAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _readingMode = value);
                        setModalState(() => _readingMode = value);
                      }
                    },
                  ),
                  RadioListTile<ReadingMode>(
                    title: const Text(
                      'Da Sinistra a Destra (Classico)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: ReadingMode.leftToRight,
                    groupValue: _readingMode,
                    activeColor: Colors.deepPurpleAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _readingMode = value);
                        setModalState(() => _readingMode = value);
                      }
                    },
                  ),
                  RadioListTile<ReadingMode>(
                    title: const Text(
                      'Verticale (Webtoon)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: ReadingMode.vertical,
                    groupValue: _readingMode,
                    activeColor: Colors.deepPurpleAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _readingMode = value);
                        setModalState(() => _readingMode = value);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // Stack posiziona i widget uno sopra l'altro (Z-index).
        // Il primo elemento è lo sfondo (il reader), i successivi sono le barre UI sovrapposte.
        child: Stack(
          children: [
            GestureDetector(
              onTapUp: (details) {
                if (!_tapToTurnEnabled) {
                  _toggleUi();
                  return;
                }

                final width = MediaQuery.of(context).size.width;
                final height = MediaQuery.of(context).size.height;
                final dx = details.globalPosition.dx;
                final dy = details.globalPosition.dy;

                if (_readingMode == ReadingMode.vertical) {
                  if (dy < height * 0.3) {
                    _goToPreviousPage();
                  } else if (dy > height * 0.7) {
                    _goToNextPage();
                  } else {
                    _toggleUi();
                  }
                } else {
                  if (dx < width * 0.3) {
                    // Tocco a sinistra
                    if (_readingMode == ReadingMode.rightToLeft) {
                      _goToNextPage();
                    } else {
                      _goToPreviousPage();
                    }
                  } else if (dx > width * 0.7) {
                    // Tocco a destra
                    if (_readingMode == ReadingMode.rightToLeft) {
                      _goToPreviousPage();
                    } else {
                      _goToNextPage();
                    }
                  } else {
                    // Tocco al centro
                    _toggleUi();
                  }
                }
              },
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _imageUrls.isEmpty
                  ? const Center(
                      child: Text(
                        'Nessuna pagina trovata.',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: _readingMode == ReadingMode.vertical
                          ? Axis.vertical
                          : Axis.horizontal,
                      reverse: _readingMode == ReadingMode.rightToLeft,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index + 1;
                        });
                      },
                      itemCount: _imageUrls.length,
                      itemBuilder: (context, index) {
                        return InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.network(
                            _imageUrls[index],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showUi ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    widget.chapterTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.screen_rotation),
                      onPressed: () {
                        // Da implementare
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: _showSettingsModal,
                    ),
                  ],
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showUi ? 0 : -120,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.85),
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 20,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pagina $_currentPage di ${_imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _currentPage.toDouble(),
                      min: 1,
                      max: _imageUrls.isEmpty
                          ? 1
                          : _imageUrls.length.toDouble(),
                      activeColor: Colors.deepPurpleAccent,
                      inactiveColor: Colors.grey,
                      onChanged: (value) {
                        _pageController.jumpToPage(value.toInt() - 1);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
