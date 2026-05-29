import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../../yomu_colors.dart';
import '../../Lingue/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  User? _user;
  bool _isUpdating = false;
  bool _isUploadingAvatar = false;
  bool _useAppLock = false;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _useAppLock = prefs.getBool('useAppLock') ?? false);
    });
  }

  Future<void> _refreshUser() async {
    final response = await Supabase.instance.client.auth.getUser();
    if (mounted && response.user != null) {
      setState(() => _user = response.user);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  // 🌟 Foto Profilo: Pick + Compress + Upload + Salva in user_metadata
  Future<void> _pickAndUploadAvatar() async {
    final loc = AppLocalizations.of(context)!;
    final picker = ImagePicker();

    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return; // L'utente ha annullato

    setState(() => _isUploadingAvatar = true);

    try {
      final userId = _user!.id;
      final bytes = await picked.readAsBytes();
      final ext = p.extension(picked.path).toLowerCase().replaceAll('.', '');
      final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext) ? ext : 'jpg';
      final contentType = safeExt == 'png' ? 'image/png'
          : safeExt == 'webp' ? 'image/webp'
          : safeExt == 'gif' ? 'image/gif'
          : 'image/jpeg';
      final filePath = '$userId.$safeExt';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);
      final avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': avatarUrl}),
      );

      await _refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.translate('acc_avatar_updated'),
              style: TextStyle(color: YomuColors.onSurface, fontWeight: FontWeight.w600),
            ),
            backgroundColor: YomuColors.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Errore upload avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.translate('acc_avatar_error'),
              style: TextStyle(color: YomuColors.onSurface),
            ),
            backgroundColor: YomuColors.error.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String _formatDate(BuildContext context, String? isoDate) {
    final loc = AppLocalizations.of(context)!;
    if (isoDate == null) return loc.translate('acc_na');
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return loc.translate('acc_na');
    }
  }

  void _showDisplayNameDialog() {
    final loc = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(
      text: _user?.userMetadata?['display_name'] ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.translate('acc_change_name'),
          style: TextStyle(
            color: YomuColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: YomuColors.onSurface),
          decoration: InputDecoration(
            hintText: loc.translate('acc_enter_name'),
            hintStyle: TextStyle(color: YomuColors.onSurfaceVariant),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: YomuColors.outlineVariant),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('common_cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isUpdating = true);
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(data: {'display_name': ctrl.text.trim()}),
              );
              await _refreshUser();
              setState(() => _isUpdating = false);
            },
            child: Text(loc.translate('common_save')),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final loc = AppLocalizations.of(context)!;
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: YomuColors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              loc.translate('acc_security'),
              style: TextStyle(
                color: YomuColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: p1,
                    obscureText: obscurePassword,
                    style: TextStyle(color: YomuColors.onSurface),
                    decoration: InputDecoration(
                      labelText: loc.translate('acc_new_password'),
                      labelStyle: TextStyle(color: YomuColors.onSurfaceVariant),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: YomuColors.outlineVariant,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: YomuColors.primary,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: YomuColors.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: () => setStateDialog(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? loc.translate('auth_min_chars')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: p2,
                    obscureText: obscurePassword,
                    style: TextStyle(color: YomuColors.onSurface),
                    decoration: InputDecoration(
                      labelText: loc.translate('acc_confirm_password'),
                      labelStyle: TextStyle(color: YomuColors.onSurfaceVariant),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: YomuColors.outlineVariant,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: YomuColors.primary,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: YomuColors.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: () => setStateDialog(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v != p1.text ? loc.translate('acc_passwords_mismatch') : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  loc.translate('common_cancel'),
                  style: TextStyle(color: YomuColors.onSurfaceVariant),
                ),
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
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);
                    try {
                      await Supabase.instance.client.auth.updateUser(
                        UserAttributes(password: p1.text),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              loc.translate('acc_password_updated'),
                              style: TextStyle(color: YomuColors.onSurface),
                            ),
                            backgroundColor: YomuColors.surfaceContainerHighest,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              loc.translate('detail_update_error'),
                              style: TextStyle(color: YomuColors.onSurface),
                            ),
                            backgroundColor: YomuColors.error.withOpacity(0.8),
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(
                  loc.translate('common_update'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.translate('acc_delete_account'),
          style: TextStyle(
            color: YomuColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          loc.translate('acc_delete_warning'),
          style: TextStyle(color: YomuColors.onSurfaceVariant, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('common_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: YomuColors.error,
              foregroundColor: YomuColors.onPrimary,
            ),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text(
              loc.translate('common_delete'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: YomuColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _infoTile(
    String label,
    String value, {
    IconData? icon,
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: icon != null
          ? Icon(icon, color: YomuColors.onSurfaceVariant, size: 22)
          : null,
      title: Text(
        label,
        style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 13),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: YomuColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: onTap != null
          ? Icon(
              trailingIcon ?? Icons.edit_outlined,
              size: 18,
              color: YomuColors.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String displayName =
        _user?.userMetadata?['display_name'] ?? 'Utente Yomu';
    final String initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'Y';
    final String provider = _user?.appMetadata['provider'] ?? 'email';
    final String? avatarUrl = _user?.userMetadata?['avatar_url'];
    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: YomuColors.surface,
      appBar: AppBar(
        backgroundColor: YomuColors.surface,
        elevation: 0,
        title: Text(
          loc.translate('set_account'),
          style: const TextStyle( fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                // 🌟 Avatar con foto profilo, icona edit e spinner di upload
                GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: YomuColors.primary.withValues(alpha: 0.15),
                        backgroundImage: hasAvatar
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: !hasAvatar
                            ? Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: YomuColors.primary,
                                ),
                              )
                            : null,
                      ),
                      // Spinner durante upload
                      if (_isUploadingAvatar)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Icona camera
                      if (!_isUploadingAvatar)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: YomuColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: YomuColors.surface, width: 2.5),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: YomuColors.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: YomuColors.onSurface,
                  ),
                ),
                Text(
                  _user!.email!,
                  style: TextStyle(
                    color: YomuColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildSection(loc.translate('acc_profile'), [
            _infoTile(
              loc.translate('acc_display_name'),
              displayName,
              icon: Icons.person_outline,
              onTap: _showDisplayNameDialog,
            ),
          ]),
          _buildSection(loc.translate('acc_details'), [
            _infoTile(
              loc.translate('acc_user_id'),
              _user!.id,
              icon: Icons.fingerprint,
              trailingIcon: Icons.copy_rounded,
              onTap: () {
                Clipboard.setData(ClipboardData(text: _user!.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.translate('acc_id_copied'))),
                );
              },
            ),
            _infoTile(loc.translate('acc_login_method'), provider, icon: Icons.login_rounded),
            _infoTile(
              loc.translate('acc_member_since'),
              _formatDate(context, _user!.createdAt),
              icon: Icons.calendar_today_outlined,
            ),
            _infoTile(
              loc.translate('acc_last_login'),
              _formatDate(context, _user!.lastSignInAt),
              icon: Icons.history_toggle_off_rounded,
            ),
          ]),
          _buildSection(loc.translate('acc_security'), [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                'Sblocco Biometrico',
                style: TextStyle(color: YomuColors.onSurface, fontSize: 16),
              ),
              subtitle: Text(
                'Richiedi impronta/Face ID all\'avvio',
                style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 13),
              ),
              value: _useAppLock,
              activeColor: YomuColors.primary,
              activeTrackColor: YomuColors.primary.withOpacity(0.3),
              inactiveThumbColor: YomuColors.outlineVariant,
              inactiveTrackColor: YomuColors.surfaceContainerHighest,
              onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('useAppLock', v);
                setState(() => _useAppLock = v);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(
                Icons.lock_outline_rounded,
                color: YomuColors.onSurface,
              ),
              title: Text(
                loc.translate('acc_change_password'),
                style: TextStyle(color: YomuColors.onSurface),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showChangePasswordDialog,
            ),
          ]),
          _buildSection(loc.translate('acc_session'), [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(Icons.logout_rounded, color: YomuColors.error),
              title: Text(
                loc.translate('acc_sign_out'),
                style: TextStyle(
                  color: YomuColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: YomuColors.surfaceContainerHigh,
                    title: Text(loc.translate('acc_sign_out_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(loc.translate('common_no')),
                      ),
                      TextButton(
                        onPressed: _signOut,
                        child: Text(
                          loc.translate('acc_sign_out_yes'),
                          style: TextStyle(color: YomuColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          _buildSection(loc.translate('acc_danger_zone'), [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(
                Icons.delete_forever_rounded,
                color: YomuColors.error,
              ),
              title: Text(
                loc.translate('acc_delete_account'),
                style: TextStyle(color: YomuColors.error),
              ),
              subtitle: Text(
                loc.translate('acc_delete_all_data'),
                style: TextStyle(
                  color: YomuColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              onTap: _showDeleteAccountDialog,
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}