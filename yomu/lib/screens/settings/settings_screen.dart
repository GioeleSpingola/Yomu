import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../yomu_colors.dart';
import 'appearance_screen.dart';
import 'reader_settings_screen.dart';
import 'account_settings_screen.dart';
import 'advanced_settings_screen.dart';
import 'statistics_screen.dart';
import '../auth_screen.dart';
import '../../Lingue/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: YomuColors.primary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? YomuColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? YomuColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: YomuColors.outline),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: YomuColors.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: YomuColors.surface,
      appBar: AppBar(
        backgroundColor: YomuColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          loc.translate('nav_settings'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: YomuColors.onSurface,
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(loc.translate('set_general')),
          _buildSettingTile(
            icon: Icons.palette_outlined,
            title: loc.translate('app_appearance'),
            subtitle: loc.translate('set_appearance_desc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppearanceScreen()),
            ),
          ),
          _buildSettingTile(
            icon: Icons.chrome_reader_mode_outlined,
            title: loc.translate('rd_reader'),
            subtitle: loc.translate('set_reader_desc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReaderSettingsScreen()),
            ),
          ),
          _buildSectionHeader(loc.translate('set_account')),
          if (user != null) ...[
            _buildSettingTile(
              icon: Icons.account_circle_outlined,
              title: loc.translate('set_account'),
              subtitle: loc.translate('set_account_desc'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              ),
            ),
            _buildSettingTile(
              icon: Icons.bar_chart_rounded,
              title: loc.translate('settings_stats'),
              subtitle: loc.translate('stats_chapters'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              ),
            ),
          ] else
            _buildSettingTile(
              icon: Icons.login_rounded,
              title: loc.translate('library_login_btn'),
              subtitle: loc.translate('set_sync_desc'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              ),
            ),
          _buildSectionHeader(loc.translate('set_system')),
          _buildSettingTile(
            icon: Icons.tune_rounded,
            title: loc.translate('adv_title'),
            subtitle: loc.translate('set_adv_desc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()),
            ),
          ),
          _buildSettingTile(
            icon: Icons.info_outline_rounded,
            title: loc.translate('set_about'),
            subtitle: loc.translate('set_version'),
            onTap: () {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
