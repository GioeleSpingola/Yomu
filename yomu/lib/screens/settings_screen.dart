import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../yomu_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Stati fittizi per la UI (in futuro li salveremo con SharedPreferences)
  String _language = 'Italiano';
  String _readingDir = 'Destra verso Sinistra';
  String _readerBg = 'Nero puro';
  int _selectedColorIndex = 0; // Indice del colore del tema scelto

  // Colori disponibili per il tema dell'app
  final List<Color> _themeColors = [
    const Color(0xFFCA98FF), // Viola Yomu (Default)
    const Color(0xFF82B1FF), // Blu
    const Color(0xFF69F0AE), // Verde Menta
    const Color(0xFFFF8A80), // Rosso Corallo
    const Color(0xFFFFD180), // Arancione
  ];

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _showYomuSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Disconnettersi?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            color: YomuColors.onSurface,
          ),
        ),
        content: const Text(
          'Verrai disconnesso dal tuo account Yomu.',
          style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
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
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              _showYomuSnackbar('Disconnesso con successo.');
            },
            child: const Text(
              'Esci',
              style: TextStyle(color: YomuColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    _showYomuSnackbar('Cache di 124 MB eliminata.');
  }

  // ─── Section label ────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: YomuColors.outline,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ─── Tile builders ────────────────────────────────────────────────────────
  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    Color iconColor = YomuColors.onSurfaceVariant,
    Color titleColor = YomuColors.onSurface,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return _TileWrapper(
      isLast: isLast,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: YomuColors.onSurfaceVariant,
                ),
              )
            : null,
        trailing: trailing != null
            ? Text(
                trailing,
                style: const TextStyle(
                  fontSize: 12,
                  color: YomuColors.onSurfaceVariant,
                ),
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: YomuColors.outlineVariant,
                size: 20,
              ),
      ),
    );
  }

  // ─── Appearance card ───────────────────
  Widget _buildAppearanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: YomuColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selettore Colore Tema
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Colore Accento',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: YomuColors.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _themeColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = _themeColors[index];
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedColorIndex = index);
                      _showYomuSnackbar('Colore aggiornato! (Mockup)');
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.black87,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: YomuColors.outlineVariant.withOpacity(0.15),
            indent: 16,
            endIndent: 16,
          ),

          // Dark mode toggle — always on, glowing
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: YomuColors.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: YomuColors.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _themeColors[_selectedColorIndex].withOpacity(
                        0.15,
                      ),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: _themeColors[_selectedColorIndex],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cinematic Dark Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: YomuColors.onSurface,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tema obsidian sempre attivo',
                          style: TextStyle(
                            fontSize: 11,
                            color: YomuColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Glowing toggle
                  Container(
                    width: 46,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _themeColors[_selectedColorIndex],
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _themeColors[_selectedColorIndex].withOpacity(
                            0.4,
                          ),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: YomuColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: tiles),
    );
  }

  void _showSelectionDialog(
    String title,
    List<String> options,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: YomuColors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            color: YomuColors.onSurface,
          ),
        ),
        children: options
            .map(
              (option) => SimpleDialogOption(
                onPressed: () {
                  onSelected(option);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: option == currentValue
                          ? YomuColors.primary
                          : YomuColors.onSurface,
                      fontWeight: option == currentValue
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

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
            Icons.settings_rounded,
            color: YomuColors.onSurfaceVariant,
          ),
        ),
        title: const Text(
          'Impostazioni',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: YomuColors.onSurface,
          ),
        ),
        centerTitle: true,
      ),

      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 100)),

          // ── Appearance ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_sectionLabel('Aspetto'), _buildAppearanceCard()],
              ),
            ),
          ),

          // ── Reader Settings (Nuova sezione utilissima) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Lettore Manga'),
                  _buildGroup([
                    _tile(
                      icon: Icons.import_contacts_rounded,
                      title: 'Verso di lettura',
                      trailing: _readingDir,
                      onTap: () => _showSelectionDialog(
                        'Verso di lettura',
                        [
                          'Destra verso Sinistra',
                          'Sinistra verso Destra',
                          'Verticale (Webtoon)',
                        ],
                        _readingDir,
                        (v) => setState(() => _readingDir = v),
                      ),
                    ),
                    _tile(
                      icon: Icons.format_color_fill_rounded,
                      title: 'Sfondo pagina',
                      trailing: _readerBg,
                      isLast: true,
                      onTap: () => _showSelectionDialog(
                        'Sfondo lettore',
                        ['Nero puro', 'Grigio scuro', 'Bianco'],
                        _readerBg,
                        (v) => setState(() => _readerBg = v),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // ── General / Data ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Dati e Sistema'),
                  _buildGroup([
                    _tile(
                      icon: Icons.language_rounded,
                      title: 'Lingua app',
                      trailing: _language,
                      onTap: () => _showSelectionDialog(
                        'Lingua',
                        ['Italiano', 'English'],
                        _language,
                        (v) => setState(() => _language = v),
                      ),
                    ),
                    _tile(
                      icon: Icons.cleaning_services_rounded,
                      title: 'Svuota cache immagini',
                      trailing: '124 MB',
                      isLast: true,
                      onTap: _clearCache,
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // ── Account ──
          if (user != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Account'),
                    _buildGroup([
                      _tile(
                        icon: Icons.account_circle_outlined,
                        title: 'Connesso come',
                        trailing: user.email,
                        onTap: null,
                      ),
                      _tile(
                        icon: Icons.logout_rounded,
                        title: 'Disconnetti',
                        iconColor: YomuColors.error,
                        titleColor: YomuColors.error,
                        isLast: true,
                        onTap: _signOut,
                      ),
                    ]),
                  ],
                ),
              ),
            ),

          // ── Version ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Center(
                child: Text(
                  'Yomu Versione 2.1.4 (Maturità Build)',
                  style: TextStyle(
                    fontSize: 11,
                    color: YomuColors.outlineVariant,
                    letterSpacing: 0.2,
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

class _TileWrapper extends StatelessWidget {
  final Widget child;
  final bool isLast;
  const _TileWrapper({required this.child, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: YomuColors.outlineVariant.withOpacity(0.15),
            indent: 68,
          ),
      ],
    );
  }
}
