import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/settings_sync_service.dart';
import '../../yomu_colors.dart';
import '../../Lingue/app_localizations.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  String _themeMode = 'Scuro';
  int _selectedColorIndex = 0;
  bool _pureBlack = true;
  String _dateFormat = 'dd/MM/yyyy';
  bool _relativeTimestamps = true;
  bool _renderDescImages = false;
  String _fontScale = 'Normale';
  bool _useSystemFont = false;
  String _appLanguage = 'Italiano';

  final List<Color> _themeColors = [
    const Color(0xFFCA98FF),
    const Color(0xFF82B1FF),
    const Color(0xFF69F0AE),
    const Color(0xFFFF8A80),
    const Color(0xFFFFD180),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _appLanguage = prefs.getString('appLanguage') ?? 'Italiano';
    setState(() {
      _selectedColorIndex = prefs.getInt('themeColorIndex') ?? 0;
      _pureBlack = prefs.getBool('pureBlack') ?? true;
      _themeMode = prefs.getString('themeMode') ?? 'Scuro';
      _dateFormat = prefs.getString('dateFormat') ?? 'dd/MM/yyyy';
      _relativeTimestamps = prefs.getBool('relativeTimestamps') ?? true;
      _renderDescImages = prefs.getBool('renderDescImages') ?? false;
      _fontScale = prefs.getString('fontScale') ?? 'Normale';
      _useSystemFont = prefs.getBool('useSystemFont') ?? false;
    });
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    SettingsSyncService.syncSetting(key, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    SettingsSyncService.syncSetting(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    SettingsSyncService.syncSetting(key, value);
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
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: YomuColors.onSurface,
          ),
        ),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<String>(
              title: Text(option['label']!, style: TextStyle(color: YomuColors.onSurface, fontSize: 15)),
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

  Widget _buildListTile({required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(title, style: TextStyle(color: YomuColors.onSurface, fontSize: 16)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 13))
          : null,
      trailing: Icon(Icons.chevron_right_rounded, color: YomuColors.outlineVariant, size: 18),
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
      title: Text(title, style: TextStyle(color: YomuColors.onSurface, fontSize: 16)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 13))
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

    String getThemeLabel(String val) {
      if (val == 'Chiaro') return loc.translate('app_theme_light');
      if (val == 'Scuro') return loc.translate('app_theme_dark');
      if (val == 'Predefinito di sistema') return loc.translate('app_theme_system');
      return val;
    }

    String getFontScaleLabel(String val) {
      if (val == 'Piccola') return loc.translate('app_size_small');
      if (val == 'Normale') return loc.translate('app_size_normal');
      if (val == 'Grande') return loc.translate('app_size_large');
      if (val == 'Extra grande') return loc.translate('app_size_xl');
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
          loc.translate('app_appearance'),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: YomuColors.onSurface,
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(loc.translate('app_theme')),
          _buildListTile(
            title: loc.translate('app_theme_app'),
            subtitle: getThemeLabel(_themeMode),
            onTap: () => _showSelectionDialog(
              loc.translate('app_theme'),
              [
                {'label': loc.translate('app_theme_light'), 'value': 'Chiaro'},
                {'label': loc.translate('app_theme_dark'), 'value': 'Scuro'},
                {'label': loc.translate('app_theme_system'), 'value': 'Predefinito di sistema'}
              ],
              _themeMode,
              (v) {
                setState(() => _themeMode = v);
                _saveString('themeMode', v);
                if (v == 'Chiaro') appThemeNotifier.value = ThemeMode.light;
                else if (v == 'Scuro') appThemeNotifier.value = ThemeMode.dark;
                else appThemeNotifier.value = ThemeMode.system;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('app_accent_color'),
                  style: TextStyle(color: YomuColors.onSurface, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _themeColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final color = _themeColors[index];
                      final isSelected = _selectedColorIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedColorIndex = index);
                          appColorNotifier.value = color;
                          _saveInt('themeColorIndex', index);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? YomuColors.onSurface : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.check_rounded, color: YomuColors.onPrimary)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _buildSwitchTile(
            title: loc.translate('app_pure_black'),
            subtitle: loc.translate('app_pure_black_desc'),
            value: _pureBlack,
            onChanged: (v) {
              setState(() => _pureBlack = v);
              _saveBool('pureBlack', v);
              appBlackNotifier.value = v;
            },
          ),
          _buildSectionHeader(loc.translate('app_text')),
          _buildListTile(
            title: loc.translate('app_text_size'),
            subtitle: getFontScaleLabel(_fontScale),
            onTap: () => _showSelectionDialog(
              loc.translate('app_text_size'),
              [
                {'label': loc.translate('app_size_small'), 'value': 'Piccola'},
                {'label': loc.translate('app_size_normal'), 'value': 'Normale'},
                {'label': loc.translate('app_size_large'), 'value': 'Grande'},
                {'label': loc.translate('app_size_xl'), 'value': 'Extra grande'}
              ],
              _fontScale,
              (v) {
                setState(() => _fontScale = v);
                _saveString('fontScale', v);
                double scale = 1.0;
                if (v == 'Piccola') scale = 0.85;
                if (v == 'Grande') scale = 1.15;
                if (v == 'Extra grande') scale = 1.30;
                appTextScaleNotifier.value = scale;
              },
            ),
          ),
          _buildSwitchTile(
            title: loc.translate('app_system_font'),
            subtitle: loc.translate('app_system_font_desc'),
            value: _useSystemFont,
            onChanged: (v) {
              setState(() => _useSystemFont = v);
              _saveBool('useSystemFont', v);
              appSystemFontNotifier.value = v;
            },
          ),
          _buildSectionHeader(loc.translate('app_display')),
          _buildListTile(
            title: loc.translate('app_language'),
            subtitle: _appLanguage,
            onTap: () => _showSelectionDialog(
              loc.translate('app_language'),
              [
                {'label': 'Italiano', 'value': 'Italiano'},
                {'label': 'English', 'value': 'English'}
              ],
              _appLanguage,
              (v) {
                setState(() => _appLanguage = v);
                _saveString('appLanguage', v);
                appLanguageNotifier.value = Locale(v == 'Italiano' ? 'it' : 'en');
              },
            ),
          ),
          _buildListTile(
            title: loc.translate('app_date_format'),
            subtitle: _dateFormat,
            onTap: () => _showSelectionDialog(
              loc.translate('app_date_format'),
              [
                {'label': 'dd/MM/yyyy', 'value': 'dd/MM/yyyy'},
                {'label': 'MM/dd/yyyy', 'value': 'MM/dd/yyyy'},
                {'label': 'yyyy-MM-dd', 'value': 'yyyy-MM-dd'}
              ],
              _dateFormat,
              (v) {
                setState(() => _dateFormat = v);
                _saveString('dateFormat', v);
              },
            ),
          ),
          _buildSwitchTile(
            title: loc.translate('app_rel_timestamps'),
            subtitle: loc.translate('app_rel_timestamps_desc'),
            value: _relativeTimestamps,
            onChanged: (v) {
              setState(() => _relativeTimestamps = v);
              _saveBool('relativeTimestamps', v);
            },
          ),
          _buildSwitchTile(
            title: loc.translate('app_desc_images'),
            subtitle: loc.translate('app_desc_images_desc'),
            value: _renderDescImages,
            onChanged: (v) {
              setState(() => _renderDescImages = v);
              _saveBool('renderDescImages', v);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}