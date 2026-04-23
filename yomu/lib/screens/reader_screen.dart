import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../yomu_colors.dart';

enum ReadingMode { leftToRight, rightToLeft, vertical }

class ReaderScreen extends StatefulWidget {
  final String mangaId;
  final List<dynamic> chapters;
  final int initialIndex;
  final int initialPage;

  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapters,
    required this.initialIndex,
    this.initialPage = 1,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _showUi = true;

  late int _currentPage;
  late PageController _pageController;
  late AnimationController _uiAnimCtrl;
  late Animation<double> _uiFade;

  ReadingMode _readingMode = ReadingMode.rightToLeft;
  bool _tapToTurnEnabled = true;

  late int _currentIndex;
  late String _chapterId;
  late String _chapterTitle;

  // ─── init / dispose ───────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);

    _uiAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _uiFade = CurvedAnimation(parent: _uiAnimCtrl, curve: Curves.easeOut);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadCurrentChapterData();
    _fetchPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _uiAnimCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── Logic (unchanged) ────────────────────────────────────────────────────
  void _loadCurrentChapterData() {
    final chapter = widget.chapters[_currentIndex];
    _chapterId = chapter['id'];
    final chapNum = chapter['attributes']['chapter'] ?? '?';
    _chapterTitle = 'Capitolo $chapNum';
    _imageUrls = [];
  }

  Future<void> _saveProgress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _imageUrls.isEmpty) return;
    try {
      await Supabase.instance.client.from('progressi').upsert({
        'user_id': user.id,
        'manga_id': widget.mangaId,
        'chapter_id': _chapterId,
        'page': _currentPage,
        'is_read': _currentPage >= _imageUrls.length,
        'last_read': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, chapter_id');
    } catch (_) {}
  }

  Future<void> _fetchPages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.mangadex.org/at-home/server/$_chapterId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final baseUrl = data['baseUrl'];
        final hash = data['chapter']['hash'];
        final filenames = data['chapter']['data'] as List<dynamic>;
        final urls = filenames.map((f) => '$baseUrl/data/$hash/$f').toList();
        if (mounted) {
          setState(() {
            _imageUrls = urls;
            _isLoading = false;
          });
          _saveProgress();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadNextChapter() {
    if (_currentIndex <= 0) {
      _showEndSnackbar();
      return;
    }
    setState(() {
      _currentIndex--;
      _isLoading = true;
      _currentPage = 1;
      _loadCurrentChapterData();
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    _fetchPages();
  }

  void _toggleUi() {
    setState(() => _showUi = !_showUi);
    if (_showUi) {
      _uiAnimCtrl.forward();
    } else {
      _uiAnimCtrl.reverse();
    }
  }

  void _goToNextPage() {
    if (_currentPage < _imageUrls.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _loadNextChapter();
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _showEndSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Hai raggiunto l\'ultimo capitolo disponibile!',
          style: TextStyle(color: YomuColors.onSurface, fontSize: 13),
        ),
        backgroundColor: YomuColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        elevation: 0,
      ),
    );
  }

  void _handleTap(TapUpDetails details) {
    if (!_tapToTurnEnabled) {
      _toggleUi();
      return;
    }
    final size = MediaQuery.of(context).size;
    final dx = details.globalPosition.dx;
    final dy = details.globalPosition.dy;

    if (_readingMode == ReadingMode.vertical) {
      if (dy < size.height * 0.3) {
        _goToPreviousPage();
      } else if (dy > size.height * 0.7) {
        _goToNextPage();
      } else {
        _toggleUi();
      }
    } else {
      if (dx < size.width * 0.3) {
        _readingMode == ReadingMode.rightToLeft
            ? _goToNextPage()
            : _goToPreviousPage();
      } else if (dx > size.width * 0.7) {
        _readingMode == ReadingMode.rightToLeft
            ? _goToPreviousPage()
            : _goToNextPage();
      } else {
        _toggleUi();
      }
    }
  }

  // ─── Settings sheet ───────────────────────────────────────────────────────
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: YomuColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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

              const Text(
                'Impostazioni lettura',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: YomuColors.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Tap to turn switch
              _buildSettingRow(
                icon: Icons.touch_app_rounded,
                title: 'Cambio pagina al tocco',
                subtitle: 'Tocca i bordi dello schermo per cambiare pagina',
                trailing: Switch(
                  value: _tapToTurnEnabled,
                  activeColor: YomuColors.primary,
                  activeTrackColor: YomuColors.primary.withOpacity(0.25),
                  inactiveThumbColor: YomuColors.outlineVariant,
                  inactiveTrackColor: YomuColors.outlineVariant.withOpacity(
                    0.2,
                  ),
                  onChanged: (v) {
                    setState(() => _tapToTurnEnabled = v);
                    setModal(() => _tapToTurnEnabled = v);
                  },
                ),
              ),

              Divider(
                color: YomuColors.outlineVariant.withOpacity(0.3),
                height: 28,
              ),

              const Text(
                'Direzione di lettura',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: YomuColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              _buildReadingModeOption(
                ctx,
                setModal,
                mode: ReadingMode.rightToLeft,
                icon: Icons.format_textdirection_r_to_l_rounded,
                label: 'Destra → Sinistra',
                subtitle: 'Stile Manga tradizionale',
              ),
              _buildReadingModeOption(
                ctx,
                setModal,
                mode: ReadingMode.leftToRight,
                icon: Icons.format_textdirection_l_to_r_rounded,
                label: 'Sinistra → Destra',
                subtitle: 'Stile classico occidentale',
              ),
              _buildReadingModeOption(
                ctx,
                setModal,
                mode: ReadingMode.vertical,
                icon: Icons.swap_vert_rounded,
                label: 'Verticale',
                subtitle: 'Stile Webtoon / manhwa',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: YomuColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: YomuColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: YomuColors.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: YomuColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildReadingModeOption(
    BuildContext ctx,
    StateSetter setModal, {
    required ReadingMode mode,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final active = _readingMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _readingMode = mode);
        setModal(() => _readingMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? YomuColors.primary.withOpacity(0.1)
              : YomuColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? YomuColors.primary.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? YomuColors.primary : YomuColors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? YomuColors.primary : YomuColors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: YomuColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              Icon(
                Icons.check_circle_rounded,
                color: YomuColors.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Page content ──
          GestureDetector(
            onTapUp: _handleTap,
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: YomuColors.primary),
                  )
                : _imageUrls.isEmpty
                ? const Center(
                    child: Text(
                      'Nessuna pagina trovata.',
                      style: TextStyle(color: YomuColors.onSurfaceVariant),
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: _readingMode == ReadingMode.vertical
                        ? Axis.vertical
                        : Axis.horizontal,
                    reverse: _readingMode == ReadingMode.rightToLeft,
                    onPageChanged: (i) {
                      setState(() => _currentPage = i + 1);
                      _saveProgress();
                    },
                    itemCount: _imageUrls.length,
                    itemBuilder: (_, i) => InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.network(
                        _imageUrls[i],
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: YomuColors.primary,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: YomuColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // ── Top bar ──
          FadeTransition(
            opacity: _uiFade,
            child: IgnorePointer(
              ignoring: !_showUi,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              _chapterTitle,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _showSettingsModal,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom bar ──
          FadeTransition(
            opacity: _uiFade,
            child: IgnorePointer(
              ignoring: !_showUi,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Page counter
                          Text(
                            '$_currentPage / ${_imageUrls.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: YomuColors.primary,
                              inactiveTrackColor: YomuColors.outlineVariant
                                  .withOpacity(0.5),
                              thumbColor: YomuColors.primary,
                              overlayColor: YomuColors.primary.withOpacity(
                                0.15,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: _currentPage.toDouble().clamp(
                                1,
                                _imageUrls.isEmpty
                                    ? 1
                                    : _imageUrls.length.toDouble(),
                              ),
                              min: 1,
                              max: _imageUrls.isEmpty
                                  ? 1
                                  : _imageUrls.length.toDouble(),
                              onChanged: (v) =>
                                  _pageController.jumpToPage(v.toInt() - 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
