import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../yomu_colors.dart';
import 'settings/reader_settings_screen.dart';
import '../Lingue/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

enum ReadingMode { leftToRight, rightToLeft, vertical }

class ReaderScreen extends StatefulWidget {
  final String mangaId;
  final List<dynamic> chapters;
  final int initialIndex;
  final int initialPage;
  final bool isWebtoon;

  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapters,
    required this.initialIndex,
    this.initialPage = 1,
    this.isWebtoon = false,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with TickerProviderStateMixin {
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _showUi = true;
  String? _errorMessage;

  late int _currentPage;
  late PageController _pageController;

  late AnimationController _uiAnimCtrl;
  late Animation<double> _uiFade;

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimCtrl;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  late String _chapterId;
  late int _currentChapterIndex;

  Timer? _readingTimer;

  ReadingMode _readingMode = ReadingMode.rightToLeft;
  bool _tapToTurnEnabled = true;
  Color _bgColor = Colors.black;
  bool _keepScreenOn = false;
  bool _showPageNumber = true;
  bool _fullscreenMode = true;
  String _doubleTapAction = 'Zoom';
  bool _showBatteryIndicator = true;
  String _scaleType = 'Adatta alla larghezza';

  bool _dataSaver = false;
  bool _downloadOnlyWifi = true;
  bool _preloadNextChapter = true;
  bool _isPreloading = false;

  final Battery _battery = Battery();
  int _batteryLevel = 100;

  // ─── Screen time tracking ──────────────────────────────────────────────────
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialIndex;
    _currentPage = widget.initialPage;
    _chapterId = widget.chapters[_currentChapterIndex]['id'];

    _loadReaderSettings();
    _initBattery();

    _pageController = PageController(initialPage: _currentPage - 1);

    _uiAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _uiFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _uiAnimCtrl, curve: Curves.easeOut),
    );

    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _zoomAnimCtrl.addListener(() {
      if (_zoomAnimation != null) {
        _transformationController.value = _zoomAnimation!.value;
      }
    });

    _readingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _incrementReadingTime();
    });

    _fetchPages();

    // Avvia il timer di sessione non appena si apre il reader
    _sessionStart = DateTime.now();
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (_) {}
  }

  Future<void> _loadReaderSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      final bgPref = prefs.getString('readerBgColor') ?? 'Nero';
      if (bgPref == 'Bianco')
        _bgColor = Colors.white;
      else if (bgPref == 'Grigio Scuro')
        _bgColor = const Color(0xFF1E1E1E);
      else
        _bgColor = Colors.black;

      if (widget.isWebtoon) {
        _readingMode = ReadingMode.vertical;
      } else {
        final modePref =
            prefs.getString('readingMode') ?? 'Destra verso Sinistra';
        if (modePref == 'Sinistra verso Destra')
          _readingMode = ReadingMode.leftToRight;
        else if (modePref == 'Verticale (Webtoon)')
          _readingMode = ReadingMode.vertical;
        else
          _readingMode = ReadingMode.rightToLeft;
      }

      _tapToTurnEnabled = prefs.getBool('tapToTurn') ?? true;
      _showPageNumber = prefs.getBool('showPageNumber') ?? true;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? false;
      _fullscreenMode = prefs.getBool('fullscreenMode') ?? true;
      _doubleTapAction = prefs.getString('doubleTapAction') ?? 'Zoom';
      _showBatteryIndicator = prefs.getBool('showBatteryIndicator') ?? false;
      _scaleType = prefs.getString('scaleType') ?? 'Adatta alla larghezza';

      _dataSaver = prefs.getBool('dataSaver') ?? false;
      _downloadOnlyWifi = prefs.getBool('downloadOnlyWifi') ?? true;
      _preloadNextChapter = prefs.getBool('preloadNextChapter') ?? true;
    });

    if (_keepScreenOn)
      WakelockPlus.enable();
    else
      WakelockPlus.disable();

    if (_fullscreenMode && !_showUi)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    else
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  BoxFit _getBoxFit() {
    switch (_scaleType) {
      case 'Adatta alla larghezza':
        return BoxFit.fitWidth;
      case 'Adatta all\'altezza':
        return BoxFit.fitHeight;
      case 'Originale':
        return BoxFit.none;
      case 'Adatta allo schermo':
      default:
        return BoxFit.contain;
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
    _loadReaderSettings();
  }

  Future<void> _saveReadingTime() async {
    if (_sessionStart == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final int minutes =
        DateTime.now().difference(_sessionStart!).inMinutes;
    if (minutes <= 0) return;

    try {
      final existing = await Supabase.instance.client
          .from('reading_stats')
          .select('minuti_lettura')
          .eq('user_id', user.id)
          .maybeSingle();

      final int current =
          (existing?['minuti_lettura'] as num?)?.toInt() ?? 0;

      await Supabase.instance.client.from('reading_stats').upsert(
        {
          'user_id': user.id,
          'minuti_lettura': current + minutes,
        },
        onConflict: 'user_id',
      );

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final dailyRow = await Supabase.instance.client
          .from('daily_stats')
          .select('minutes_read')
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();
      final int dailyCurrent =
          (dailyRow?['minutes_read'] as num?)?.toInt() ?? 0;
      await Supabase.instance.client.from('daily_stats').upsert(
        {
          'user_id': user.id,
          'date': today,
          'minutes_read': dailyCurrent + minutes,
        },
        onConflict: 'user_id, date',
      );
    } catch (e) {
      debugPrint('Errore salvataggio reading time: $e');
    }
  }

  Future<void> _incrementReadingTime() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('reading_stats')
          .select('minuti_lettura')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        final currentMinutes = (response['minuti_lettura'] as num?)?.toInt() ?? 0;
        await Supabase.instance.client
            .from('reading_stats')
            .update({'minuti_lettura': currentMinutes + 1})
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client
            .from('reading_stats')
            .insert({'user_id': user.id, 'minuti_lettura': 1});
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final dailyRow = await Supabase.instance.client
          .from('daily_stats')
          .select('minutes_read')
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();
      final int dailyCurrent =
          (dailyRow?['minutes_read'] as num?)?.toInt() ?? 0;
      await Supabase.instance.client.from('daily_stats').upsert(
        {
          'user_id': user.id,
          'date': today,
          'minutes_read': dailyCurrent + 1,
        },
        onConflict: 'user_id, date',
      );
    } catch (e) {
      debugPrint('Errore salvataggio tempo: $e');
    }
  }

  @override
  void dispose() {
    // Salva il tempo di lettura prima di chiudere
    _saveReadingTime();

    _pageController.dispose();
    _uiAnimCtrl.dispose();
    _zoomAnimCtrl.dispose();
    _transformationController.dispose();
    _readingTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_keepScreenOn) WakelockPlus.disable();
    super.dispose();
  }

  void _showQuickSettingsSheet() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: YomuColors.surfaceContainerHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: YomuColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      loc.translate('reader_quick_mode'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: YomuColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip(
                          label: loc.translate('reader_mode_normal'),
                          icon: Icons.keyboard_arrow_left_rounded,
                          isSelected: _readingMode == ReadingMode.rightToLeft,
                          onTap: () {
                            _updateSetting(
                              'readingMode',
                              'Destra verso Sinistra',
                            );
                            setModalState(() {});
                          },
                        ),
                        _buildChoiceChip(
                          label: loc.translate('reader_mode_comic'),
                          icon: Icons.keyboard_arrow_right_rounded,
                          isSelected: _readingMode == ReadingMode.leftToRight,
                          onTap: () {
                            _updateSetting(
                              'readingMode',
                              'Sinistra verso Destra',
                            );
                            setModalState(() {});
                          },
                        ),
                        _buildChoiceChip(
                          label: loc.translate('reader_mode_webtoon'),
                          icon: Icons.arrow_downward_rounded,
                          isSelected: _readingMode == ReadingMode.vertical,
                          onTap: () {
                            _updateSetting(
                              'readingMode',
                              'Verticale (Webtoon)',
                            );
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      loc.translate('reader_quick_bg'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: YomuColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildColorChip(Colors.black, 'Nero', setModalState),
                        const SizedBox(width: 12),
                        _buildColorChip(
                          const Color(0xFF1E1E1E),
                          'Grigio Scuro',
                          setModalState,
                        ),
                        const SizedBox(width: 12),
                        _buildColorChip(
                          Colors.white,
                          'Bianco',
                          setModalState,
                          isLight: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? YomuColors.primary.withOpacity(0.15)
              : YomuColors.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? YomuColors.primary : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  isSelected ? YomuColors.primary : YomuColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? YomuColors.primary
                    : YomuColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChip(
    Color color,
    String prefValue,
    StateSetter setModalState, {
    bool isLight = false,
  }) {
    final bool isSelected = (_bgColor.value == color.value);
    return GestureDetector(
      onTap: () {
        _updateSetting('readerBgColor', prefValue);
        setModalState(() {});
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? YomuColors.primary
                : (isLight ? YomuColors.outlineVariant : Colors.transparent),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check_rounded,
                color: isLight ? Colors.black : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  Future<void> _fetchPages() async {
    setState(() {
      _isLoading = true;
      _imageUrls.clear();
      _errorMessage = null;
    });

    if (_downloadOnlyWifi) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        bool isMobile = false;
        if (connectivityResult is List) {
          isMobile = (connectivityResult as List)
              .contains(ConnectivityResult.mobile);
        } else {
          isMobile = connectivityResult == ConnectivityResult.mobile;
        }

        if (isMobile) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  "Connessione dati rilevata.\nDisattiva 'Solo Wi-Fi' in Impostazioni > Avanzate per leggere.";
            });
          }
          return;
        }
      } catch (_) {}
    }

    try {
      final url = Uri.parse(
          'https://api.mangadex.org/at-home/server/$_chapterId');
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final baseUrl = data['baseUrl'];
        final hash = data['chapter']['hash'];

        final String arrayName = _dataSaver ? 'dataSaver' : 'data';
        final String folderName = _dataSaver ? 'data-saver' : 'data';

        final pages = data['chapter'][arrayName] as List;

        if (mounted) {
          setState(() {
            _imageUrls =
                pages.map((p) => '$baseUrl/$folderName/$hash/$p').toList();
            _isLoading = false;
            _isPreloading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkPreload() {
    for (int p = _currentPage;
        p <= _currentPage + 2 && p < _imageUrls.length;
        p++) {
      precacheImage(CachedNetworkImageProvider(_imageUrls[p]), context);
    }

    if (!_preloadNextChapter || _isPreloading || _imageUrls.isEmpty) return;

    if (_currentPage >= _imageUrls.length - 2) {
      int nextIndex = _currentChapterIndex - 1;
      if (nextIndex >= 0 && nextIndex < widget.chapters.length) {
        _preloadChapter(widget.chapters[nextIndex]['id']);
      }
    }
  }

  Future<void> _preloadChapter(String chapterId) async {
    _isPreloading = true;
    try {
      final url = Uri.parse(
          'https://api.mangadex.org/at-home/server/$chapterId');
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final baseUrl = data['baseUrl'];
        final hash = data['chapter']['hash'];
        final String arrayName = _dataSaver ? 'dataSaver' : 'data';
        final String folderName = _dataSaver ? 'data-saver' : 'data';
        final pages = data['chapter'][arrayName] as List;

        if (pages.isNotEmpty && mounted) {
          final firstPageUrl = '$baseUrl/$folderName/$hash/${pages[0]}';
          precacheImage(CachedNetworkImageProvider(firstPageUrl), context);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _imageUrls.isEmpty) return;
    try {
      final bool isFinished = _currentPage >= _imageUrls.length;
      await Supabase.instance.client.from('progressi').upsert({
        'user_id': user.id,
        'manga_id': widget.mangaId,
        'chapter_id': _chapterId,
        'page': _currentPage,
        'is_read': isFinished,
        'last_read': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, chapter_id');

      final libData = await Supabase.instance.client
          .from('libreria')
          .select('status, capitoli_totali')
          .eq('user_id', user.id)
          .eq('manga_id', widget.mangaId)
          .maybeSingle();

      if (libData != null) {
        String currentStatus = libData['status'] ?? 'reading';
        int totali = libData['capitoli_totali'] ?? 0;
        Map<String, dynamic> libraryUpdate = {
          'last_read': DateTime.now().toUtc().toIso8601String(),
        };

        if (isFinished) {
          final countResponse = await Supabase.instance.client
              .from('progressi')
              .select('id')
              .eq('user_id', user.id)
              .eq('manga_id', widget.mangaId)
              .eq('is_read', true)
              .count(CountOption.exact);
          int letti = countResponse.count ?? 0;
          libraryUpdate['capitoli_letti'] = letti;
          if (letti >= totali && totali > 0)
            libraryUpdate['status'] = 'completed';
          else if (currentStatus == 'plan_to_read' ||
              currentStatus == 'completed')
            libraryUpdate['status'] = 'reading';
        } else {
          if (currentStatus == 'plan_to_read')
            libraryUpdate['status'] = 'reading';
        }

        await Supabase.instance.client
            .from('libreria')
            .update(libraryUpdate)
            .eq('user_id', user.id)
            .eq('manga_id', widget.mangaId);
      }
    } catch (e) {
      debugPrint('Errore salvataggio progresso: $e');
    }
  }

  void _loadAdjacentChapter(int delta) {
    final loc = AppLocalizations.of(context)!;
    int nextIndex = _currentChapterIndex + delta;
    if (nextIndex >= 0 && nextIndex < widget.chapters.length) {
      // Salviamo il tempo del capitolo corrente prima di cambiare
      _saveReadingTime();
      _sessionStart = DateTime.now();

      setState(() {
        _currentChapterIndex = nextIndex;
        _chapterId = widget.chapters[_currentChapterIndex]['id'];
        _currentPage = 1;
      });
      _transformationController.value = Matrix4.identity();
      _pageController.jumpToPage(0);
      _fetchPages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delta < 0
                ? loc.translate('reader_no_next')
                : loc.translate('reader_no_prev'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onTap(TapUpDetails details) {
    if (!_tapToTurnEnabled && _showUi) {
      _toggleUi();
      return;
    }

    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final dx = details.globalPosition.dx;
    final dy = details.globalPosition.dy;

    if (dx > w * 0.3 && dx < w * 0.7 && dy > h * 0.25 && dy < h * 0.75) {
      _toggleUi();
      return;
    }

    if (_readingMode == ReadingMode.vertical) {
      if (dy < h * 0.3)
        _goToPage(_currentPage - 1);
      else if (dy > h * 0.7)
        _goToPage(_currentPage + 1);
    } else if (_readingMode == ReadingMode.leftToRight) {
      if (dx < w * 0.3)
        _goToPage(_currentPage - 1);
      else if (dx > w * 0.7)
        _goToPage(_currentPage + 1);
    } else {
      if (dx < w * 0.3)
        _goToPage(_currentPage + 1);
      else if (dx > w * 0.7)
        _goToPage(_currentPage - 1);
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _onDoubleTap() {
    if (_doubleTapAction == 'Pagina successiva') {
      _goToPage(_currentPage + 1);
    } else if (_doubleTapAction == 'Zoom') {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final Matrix4 endMatrix;

      if (_transformationController.value.isIdentity()) {
        endMatrix = Matrix4.identity()
          ..translate(-position.dx, -position.dy)
          ..scale(2.0);
      } else {
        endMatrix = Matrix4.identity();
      }

      _zoomAnimation = Matrix4Tween(
        begin: _transformationController.value,
        end: endMatrix,
      ).animate(CurveTween(curve: Curves.easeInOut).animate(_zoomAnimCtrl));

      _zoomAnimCtrl.forward(from: 0);
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _imageUrls.length) return;
    _pageController.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _toggleUi() {
    setState(() => _showUi = !_showUi);
    if (_showUi) {
      _uiAnimCtrl.forward();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      _uiAnimCtrl.reverse();
      if (_fullscreenMode) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final curChpNum =
        widget.chapters[_currentChapterIndex]['attributes']['chapter'] ?? '?';
    final isReversed = _readingMode == ReadingMode.rightToLeft;
    final scrollAxis =
        _readingMode == ReadingMode.vertical ? Axis.vertical : Axis.horizontal;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          GestureDetector(
            onTapUp: _onTap,
            onDoubleTapDown: _onDoubleTapDown,
            onDoubleTap: _onDoubleTap,
            child: _isLoading
                ? Center(
                    child:
                        CircularProgressIndicator(color: YomuColors.primary),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded,
                                  size: 56,
                                  color: YomuColors.outlineVariant),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _imageUrls.isEmpty
                        ? Center(
                            child: Text(
                              loc.translate('reader_no_pages'),
                              style:
                                  const TextStyle(color: Colors.white70),
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            reverse: isReversed,
                            scrollDirection: scrollAxis,
                            physics: const ClampingScrollPhysics(),
                            itemCount: _imageUrls.length,
                            onPageChanged: (idx) {
                              setState(() => _currentPage = idx + 1);
                              _transformationController.value =
                                  Matrix4.identity();
                              _saveProgress();
                              _checkPreload();
                            },
                            itemBuilder: (ctx, i) => InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              minScale: 1.0,
                              maxScale: 3.0,
                              child: CachedNetworkImage(
                                imageUrl: _imageUrls[i],
                                fit: _getBoxFit(),
                                fadeInDuration:
                                    const Duration(milliseconds: 150),
                                progressIndicatorBuilder:
                                    (context, url, progress) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: progress.progress,
                                      color: YomuColors.primary
                                          .withOpacity(0.5),
                                    ),
                                  );
                                },
                                errorWidget: (context, url, error) =>
                                    Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image_rounded,
                                          color: YomuColors.outlineVariant,
                                          size: 48),
                                      const SizedBox(height: 8),
                                      Text(
                                        loc.translate('common_error'),
                                        style: TextStyle(
                                            color:
                                                YomuColors.outlineVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),

          if (!_showUi &&
              (_showPageNumber || _showBatteryIndicator) &&
              !_isLoading &&
              _imageUrls.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showPageNumber)
                        Text(
                          '$_currentPage / ${_imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      if (_showPageNumber && _showBatteryIndicator)
                        const SizedBox(width: 8),
                      if (_showBatteryIndicator) ...[
                        Icon(
                          Icons.battery_full_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_batteryLevel%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          IgnorePointer(
            ignoring: !_showUi,
            child: FadeTransition(
              opacity: _uiFade,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent
                    ],
                  ),
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    '${loc.translate('detail_chapter')} $curChpNum',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: _showQuickSettingsSheet,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReaderSettingsScreen(),
                          ),
                        ).then((_) => _loadReaderSettings());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          IgnorePointer(
            ignoring: !_showUi,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FadeTransition(
                opacity: _uiFade,
                child: Container(
                  height: 130,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => _loadAdjacentChapter(1),
                          ),
                          Text(
                            _imageUrls.isEmpty
                                ? loc.translate('common_loading')
                                : '$_currentPage / ${_imageUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => _loadAdjacentChapter(-1),
                          ),
                        ],
                      ),
                      if (_imageUrls.isNotEmpty)
                        SizedBox(
                          height: 24,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: YomuColors.primary,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: YomuColors.primary,
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: _currentPage.toDouble().clamp(
                                    1,
                                    _imageUrls.length.toDouble(),
                                  ),
                              min: 1,
                              max: _imageUrls.length.toDouble(),
                              onChanged: (v) =>
                                  _pageController.jumpToPage(v.toInt() - 1),
                            ),
                          ),
                        ),
                    ],
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