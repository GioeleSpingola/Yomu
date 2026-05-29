import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../yomu_colors.dart';
import '../../Lingue/app_localizations.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:workmanager/workmanager.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  bool _autoUpdateLibrary = true;
  bool _backgroundSync = false;
  String _updateFrequency = 'Ogni 6 ore';
  bool _downloadOnlyWifi = true;
  bool _preloadNextChapter = true;
  String _imageQuality = 'Alta';
  bool _dataSaver = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _updateWorkmanager() {
    if (!_backgroundSync || _updateFrequency == 'Solo manuale') {
      Workmanager().cancelByUniqueName("yomu-library-sync");
    } else {
      int hours = 6;
      if (_updateFrequency == 'Ogni ora') hours = 1;
      if (_updateFrequency == 'Ogni 6 ore') hours = 6;
      if (_updateFrequency == 'Ogni 12 ore') hours = 12;
      if (_updateFrequency == 'Ogni giorno') hours = 24;

      Workmanager().registerPeriodicTask(
        "yomu-library-sync",
        "librarySyncTask",
        frequency: Duration(hours: hours),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        initialDelay: const Duration(minutes: 5),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        tag: 'yomu-sync',
      );
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoUpdateLibrary = prefs.getBool('autoUpdateLibrary') ?? true;
      _backgroundSync = prefs.getBool('backgroundSync') ?? false;
      _updateFrequency = prefs.getString('updateFrequency') ?? 'Ogni 6 ore';
      _downloadOnlyWifi = prefs.getBool('downloadOnlyWifi') ?? true;
      _preloadNextChapter = prefs.getBool('preloadNextChapter') ?? true;
      _imageQuality = prefs.getString('imageQuality') ?? 'Alta';
      _dataSaver = prefs.getBool('dataSaver') ?? false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
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

  void _showClearCacheDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.translate('adv_clear_cache'),
          style: TextStyle(
            color: YomuColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          loc.translate('adv_clear_cache_desc'),
          style: TextStyle(color: YomuColors.onSurfaceVariant, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('common_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: YomuColors.primary,
              foregroundColor: YomuColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();

              await DefaultCacheManager().emptyCache();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    loc.translate('adv_cache_cleared'),
                    style: TextStyle(
                      color: YomuColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: YomuColors.surfaceContainerHighest,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              loc.translate('common_clear'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
    IconData? trailingIcon,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? YomuColors.onSurface,
          fontSize: 16,
        ),
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
        trailingIcon ?? Icons.chevron_right_rounded,
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

    String getFreqLabel(String val) {
      if (val == 'Ogni ora') return loc.translate('adv_freq_hour');
      if (val == 'Ogni 6 ore') return loc.translate('adv_freq_6h');
      if (val == 'Ogni 12 ore') return loc.translate('adv_freq_12h');
      if (val == 'Ogni giorno') return loc.translate('adv_freq_day');
      if (val == 'Solo manuale') return loc.translate('adv_freq_manual');
      return val;
    }

    String getQualityLabel(String val) {
      if (val == 'Bassa') return loc.translate('adv_qual_low');
      if (val == 'Media') return loc.translate('adv_qual_med');
      if (val == 'Alta') return loc.translate('adv_qual_high');
      if (val == 'Originale') return loc.translate('adv_qual_orig');
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
          loc.translate('adv_title'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: YomuColors.onSurface,
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(loc.translate('adv_library')),
          _buildSwitchTile(
            title: loc.translate('adv_auto_update'),
            subtitle: loc.translate('adv_auto_update_desc'),
            value: _autoUpdateLibrary,
            onChanged: (v) {
              setState(() => _autoUpdateLibrary = v);
              _saveBool('autoUpdateLibrary', v);
            },
          ),
          _buildListTile(
            title: loc.translate('adv_update_freq'),
            subtitle: getFreqLabel(_updateFrequency),
            onTap: () => _showSelectionDialog(
              loc.translate('adv_update_freq'),
              [
                {'label': loc.translate('adv_freq_hour'), 'value': 'Ogni ora'},
                {'label': loc.translate('adv_freq_6h'), 'value': 'Ogni 6 ore'},
                {
                  'label': loc.translate('adv_freq_12h'),
                  'value': 'Ogni 12 ore',
                },
                {
                  'label': loc.translate('adv_freq_day'),
                  'value': 'Ogni giorno',
                },
                {
                  'label': loc.translate('adv_freq_manual'),
                  'value': 'Solo manuale',
                },
              ],
              _updateFrequency,
              (v) {
                setState(() => _updateFrequency = v);
                _saveString('updateFrequency', v);
                _updateWorkmanager();
              },
            ),
          ),
          _buildSwitchTile(
            title: loc.translate('adv_bg_sync'),
            subtitle: loc.translate('adv_bg_sync_desc'),
            value: _backgroundSync,
            onChanged: (v) {
              setState(() => _backgroundSync = v);
              _saveBool('backgroundSync', v);
              _updateWorkmanager();
            },
          ),
          _buildSectionHeader(loc.translate('adv_network')),
          _buildSwitchTile(
            title: loc.translate('adv_wifi_only'),
            subtitle: loc.translate('adv_wifi_only_desc'),
            value: _downloadOnlyWifi,
            onChanged: (v) {
              setState(() => _downloadOnlyWifi = v);
              _saveBool('downloadOnlyWifi', v);
            },
          ),
          _buildSwitchTile(
            title: loc.translate('adv_data_saver'),
            subtitle: loc.translate('adv_data_saver_desc'),
            value: _dataSaver,
            onChanged: (v) {
              setState(() => _dataSaver = v);
              _saveBool('dataSaver', v);
            },
          ),
          _buildListTile(
            title: loc.translate('adv_image_quality'),
            subtitle: getQualityLabel(_imageQuality),
            onTap: () => _showSelectionDialog(
              loc.translate('adv_image_quality'),
              [
                {'label': loc.translate('adv_qual_low'), 'value': 'Bassa'},
                {'label': loc.translate('adv_qual_med'), 'value': 'Media'},
                {'label': loc.translate('adv_qual_high'), 'value': 'Alta'},
                {'label': loc.translate('adv_qual_orig'), 'value': 'Originale'},
              ],
              _imageQuality,
              (v) {
                setState(() => _imageQuality = v);
                _saveString('imageQuality', v);
              },
            ),
          ),
          _buildSwitchTile(
            title: loc.translate('adv_preload_next'),
            subtitle: loc.translate('adv_preload_next_desc'),
            value: _preloadNextChapter,
            onChanged: (v) {
              setState(() => _preloadNextChapter = v);
              _saveBool('preloadNextChapter', v);
            },
          ),
          _buildSectionHeader(loc.translate('adv_storage')),
          _buildListTile(
            title: loc.translate('adv_clear_cache'),
            subtitle: loc.translate('adv_clear_local'),
            onTap: _showClearCacheDialog,
            trailingIcon: Icons.delete_outline_rounded,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
