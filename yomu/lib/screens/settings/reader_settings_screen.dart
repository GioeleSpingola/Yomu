import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../yomu_colors.dart';
import '../../Lingue/app_localizations.dart';

class ReaderSettingsScreen extends StatefulWidget {
  const ReaderSettingsScreen({super.key});

  @override
  State<ReaderSettingsScreen> createState() => _ReaderSettingsScreenState();
}

class _ReaderSettingsScreenState extends State<ReaderSettingsScreen> {
  String _readingMode = 'Destra verso Sinistra';
  String _bgColor = 'Nero';
  bool _tapToTurn = true;
  bool _keepScreenOn = true;
  bool _showPageNumber = true;
  bool _fullscreenMode = true;
  String _doubleTapAction = 'Zoom';
  bool _showBatteryIndicator = false;
  bool _cropBorders = false;
  String _scaleType = 'Adatta alla larghezza';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readingMode = prefs.getString('readingMode') ?? 'Destra verso Sinistra';
      _bgColor = prefs.getString('readerBgColor') ?? 'Nero';
      _tapToTurn = prefs.getBool('tapToTurn') ?? true;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
      _showPageNumber = prefs.getBool('showPageNumber') ?? true;
      _fullscreenMode = prefs.getBool('fullscreenMode') ?? true;
      _doubleTapAction = prefs.getString('doubleTapAction') ?? 'Zoom';
      _showBatteryIndicator = prefs.getBool('showBatteryIndicator') ?? false;
      _cropBorders = prefs.getBool('cropBorders') ?? false;
      _scaleType = prefs.getString('scaleType') ?? 'Adatta alla larghezza';
    });
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showSelectionDialog(
    String title,
    List<Map<String, String>> options,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: YomuColors.onSurface,
          ),
        ),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<String>(
              title: Text(
                option['label']!,
                style: TextStyle(color: YomuColors.onSurface, fontSize: 15),
              ),
              value: option['value']!,
              groupValue: currentValue,
              activeColor: YomuColors.primary,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: YomuColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        title,
        style: TextStyle(color: YomuColors.onSurface, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: YomuColors.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: YomuColors.outlineVariant,
        size: 18,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        title,
        style: TextStyle(color: YomuColors.onSurface, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: YomuColors.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          : null,
      value: value,
      activeColor: YomuColors.primary,
      activeTrackColor: YomuColors.primary.withOpacity(0.3),
      inactiveThumbColor: YomuColors.outlineVariant,
      inactiveTrackColor: YomuColors.surfaceContainerHighest,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    String getModeLabel(String val) {
      if (val == 'Destra verso Sinistra') return loc.translate('rd_dir_rtl');
      if (val == 'Sinistra verso Destra') return loc.translate('rd_dir_ltr');
      if (val == 'Verticale (Webtoon)') return loc.translate('rd_dir_vertical');
      return val;
    }

    String getActionLabel(String val) {
      if (val == 'Zoom') return loc.translate('rd_action_zoom');
      if (val == 'Pagina successiva') return loc.translate('rd_action_next');
      if (val == 'Nessuna') return loc.translate('rd_action_none');
      return val;
    }

    String getBgLabel(String val) {
      if (val == 'Nero') return loc.translate('reader_bg_black');
      if (val == 'Grigio Scuro') return loc.translate('reader_bg_dark_grey');
      if (val == 'Bianco') return loc.translate('reader_bg_white');
      return val;
    }

    String getScaleLabel(String val) {
      if (val == 'Adatta alla larghezza') return loc.translate('rd_scale_width');
      if (val == 'Adatta all\'altezza') return loc.translate('rd_scale_height');
      if (val == 'Adatta allo schermo') return loc.translate('rd_scale_screen');
      if (val == 'Originale') return loc.translate('rd_scale_orig');
      return val;
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
          loc.translate('rd_reader'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: YomuColors.onSurface,
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(loc.translate('rd_navigation')),
          _buildListTile(
            title: loc.translate('rd_reading_dir'),
            subtitle: getModeLabel(_readingMode),
            onTap: () => _showSelectionDialog(
              loc.translate('rd_reading_dir'),
              [
                {'label': loc.translate('rd_dir_rtl'), 'value': 'Destra verso Sinistra'},
                {'label': loc.translate('rd_dir_ltr'), 'value': 'Sinistra verso Destra'},
                {'label': loc.translate('rd_dir_vertical'), 'value': 'Verticale (Webtoon)'},
              ],
              _readingMode,
              (v) {
                setState(() => _readingMode = v);
                _saveString('readingMode', v);
              },
            ),
          ),
          _buildSwitchTile(
            title: loc.translate('rd_tap_to_turn'),
            subtitle: loc.translate('rd_tap_to_turn_desc'),
            value: _tapToTurn,
            onChanged: (v) {
              setState(() => _tapToTurn = v);
              _saveBool('tapToTurn', v);
            },
          ),
          _buildListTile(
            title: loc.translate('rd_double_tap'),
            subtitle: getActionLabel(_doubleTapAction),
            onTap: () => _showSelectionDialog(
              loc.translate('rd_double_tap_action'),
              [
                {'label': loc.translate('rd_action_zoom'), 'value': 'Zoom'},
                {'label': loc.translate('rd_action_next'), 'value': 'Pagina successiva'},
                {'label': loc.translate('rd_action_none'), 'value': 'Nessuna'},
              ],
              _doubleTapAction,
              (v) {
                setState(() => _doubleTapAction = v);
                _saveString('doubleTapAction', v);
              },
            ),
          ),
          _buildSectionHeader(loc.translate('rd_appearance')),
          _buildListTile(
            title: loc.translate('rd_bg_color'),
            subtitle: getBgLabel(_bgColor),
            onTap: () => _showSelectionDialog(
              loc.translate('rd_bg_color'),
              [
                {'label': loc.translate('reader_bg_black'), 'value': 'Nero'},
                {'label': loc.translate('reader_bg_dark_grey'), 'value': 'Grigio Scuro'},
                {'label': loc.translate('reader_bg_white'), 'value': 'Bianco'},
              ],
              _bgColor,
              (v) {
                setState(() => _bgColor = v);
                _saveString('readerBgColor', v);
              },
            ),
          ),
          _buildListTile(
            title: loc.translate('rd_scale_type'),
            subtitle: getScaleLabel(_scaleType),
            onTap: () => _showSelectionDialog(
              loc.translate('rd_scale_type'),
              [
                {'label': loc.translate('rd_scale_width'), 'value': 'Adatta alla larghezza'},
                {'label': loc.translate('rd_scale_height'), 'value': 'Adatta all\'altezza'},
                {'label': loc.translate('rd_scale_screen'), 'value': 'Adatta allo schermo'},
                {'label': loc.translate('rd_scale_orig'), 'value': 'Originale'},
              ],
              _scaleType,
              (v) {
                setState(() => _scaleType = v);
                _saveString('scaleType', v);
              },
            ),
          ),
          _buildSectionHeader(loc.translate('rd_system')),
          _buildSwitchTile(
            title: loc.translate('rd_keep_awake'),
            subtitle: loc.translate('rd_keep_awake_desc'),
            value: _keepScreenOn,
            onChanged: (v) {
              setState(() => _keepScreenOn = v);
              _saveBool('keepScreenOn', v);
            },
          ),
          _buildSwitchTile(
            title: loc.translate('rd_fullscreen'),
            subtitle: loc.translate('rd_fullscreen_desc'),
            value: _fullscreenMode,
            onChanged: (v) {
              setState(() => _fullscreenMode = v);
              _saveBool('fullscreenMode', v);
            },
          ),
          _buildSectionHeader(loc.translate('rd_overlay')),
          _buildSwitchTile(
            title: loc.translate('rd_show_page_num'),
            subtitle: loc.translate('rd_show_page_num_desc'),
            value: _showPageNumber,
            onChanged: (v) {
              setState(() => _showPageNumber = v);
              _saveBool('showPageNumber', v);
            },
          ),
          _buildSwitchTile(
            title: loc.translate('rd_show_battery'),
            subtitle: loc.translate('rd_show_battery_desc'),
            value: _showBatteryIndicator,
            onChanged: (v) {
              setState(() => _showBatteryIndicator = v);
              _saveBool('showBatteryIndicator', v);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}