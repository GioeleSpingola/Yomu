import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import '../yomu_colors.dart';
import '../Lingue/app_localizations.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLogin = true; 

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    
    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) _showMessage(e.message, isError: true);
    } catch (e) {
      if (mounted) _showMessage('${loc.translate('common_error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 STEP 1: L'utente inserisce l'email
  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final loc = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.translate('auth_recover_password'), 
          style: TextStyle( fontWeight: FontWeight.w700, color: YomuColors.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.translate('auth_recover_desc'), 
              style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: resetCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: YomuColors.onSurface),
              onSubmitted: (_) => _submitResetEmail(ctx, resetCtrl, loc),
              decoration: InputDecoration(
                hintText: loc.translate('auth_your_email'),
                hintStyle: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
                prefixIcon: Icon(Icons.mark_email_read_outlined, color: YomuColors.onSurfaceVariant),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.outlineVariant)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.primary, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text(loc.translate('common_cancel'), style: TextStyle(color: YomuColors.onSurfaceVariant))
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: YomuColors.primary,
              foregroundColor: YomuColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _submitResetEmail(ctx, resetCtrl, loc),
            child: Text(loc.translate('auth_send_link'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitResetEmail(BuildContext ctx, TextEditingController resetCtrl, AppLocalizations loc) async {
    final email = resetCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(loc.translate('auth_invalid_email'), isError: true);
      return;
    }
    
    Navigator.pop(ctx);
    
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        _showMessage(loc.translate('auth_link_sent'), isError: false);
        // 🌟 STEP 2: Mostra il dialog per inserire il codice OTP
        _showOtpDialog(email);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(loc.translate('auth_email_error'), isError: true);
      }
    }
  }

  // 🌟 STEP 2: L'utente inserisce il codice OTP ricevuto via email
  void _showOtpDialog(String email) {
    final otpCtrl = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: YomuColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.translate('auth_otp_title'),
          style: TextStyle(fontWeight: FontWeight.w700, color: YomuColors.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.translate('auth_otp_desc'),
              style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              maxLength: 8,
              style: TextStyle(
                color: YomuColors.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              onSubmitted: (_) => _submitOtp(ctx, email, otpCtrl, loc),
              decoration: InputDecoration(
                hintText: loc.translate('auth_otp_hint'),
                hintStyle: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 16, letterSpacing: 2),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.outlineVariant)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.primary, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('common_cancel'), style: TextStyle(color: YomuColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: YomuColors.primary,
              foregroundColor: YomuColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _submitOtp(ctx, email, otpCtrl, loc),
            child: Text(loc.translate('auth_otp_verify'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOtp(BuildContext ctx, String email, TextEditingController otpCtrl, AppLocalizations loc) async {
    final otp = otpCtrl.text.trim();
    if (otp.length != 8) {
      _showMessage(loc.translate('auth_otp_invalid'), isError: true);
      return;
    }

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );

      if (mounted) {
        Navigator.pop(ctx);
        // 🌟 STEP 3: L'OTP è valido! Ora chiediamo la nuova password
        _showNewPasswordDialog();
      }
    } catch (e) {
      if (mounted) {
        _showMessage(loc.translate('auth_otp_error'), isError: true);
      }
    }
  }

  // 🌟 STEP 3: L'utente sceglie la nuova password
  void _showNewPasswordDialog() {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final loc = AppLocalizations.of(context)!;
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: YomuColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            loc.translate('auth_new_password_title'),
            style: TextStyle(fontWeight: FontWeight.w700, color: YomuColors.onSurface),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.translate('auth_new_password_desc'),
                  style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: p1,
                  obscureText: obscure,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: YomuColors.onSurface),
                  decoration: InputDecoration(
                    labelText: loc.translate('auth_password'),
                    labelStyle: TextStyle(color: YomuColors.onSurfaceVariant),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.outlineVariant)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.primary, width: 2)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: YomuColors.onSurfaceVariant, size: 20,
                      ),
                      onPressed: () => setStateDialog(() => obscure = !obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? loc.translate('auth_min_chars') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: p2,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: YomuColors.onSurface),
                  onFieldSubmitted: (_) => _submitNewPassword(ctx, formKey, p1, p2, loc),
                  decoration: InputDecoration(
                    labelText: loc.translate('auth_new_password_confirm'),
                    labelStyle: TextStyle(color: YomuColors.onSurfaceVariant),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.outlineVariant)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: YomuColors.primary, width: 2)),
                  ),
                  validator: (v) => v != p1.text ? loc.translate('auth_passwords_mismatch') : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.translate('common_cancel'), style: TextStyle(color: YomuColors.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: YomuColors.primary,
                foregroundColor: YomuColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _submitNewPassword(ctx, formKey, p1, p2, loc),
              child: Text(loc.translate('auth_confirm_reset'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitNewPassword(
    BuildContext ctx,
    GlobalKey<FormState> formKey,
    TextEditingController p1,
    TextEditingController p2,
    AppLocalizations loc,
  ) async {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(ctx);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: p1.text),
      );
      if (mounted) {
        _showMessage(loc.translate('auth_password_reset_ok'), isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(loc.translate('auth_password_reset_error'), isError: true);
      }
    }
  }

  void _showMessage(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: YomuColors.onSurface)),
        backgroundColor: isError ? YomuColors.error.withOpacity(0.9) : YomuColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: YomuColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: YomuColors.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 64,
                    color: YomuColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? loc.translate('auth_welcome_back') : loc.translate('auth_join'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: YomuColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? loc.translate('auth_login_desc') : loc.translate('auth_register_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: YomuColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: YomuColors.onSurface),
                    decoration: InputDecoration(
                      labelText: loc.translate('auth_email'),
                      labelStyle: TextStyle(color: YomuColors.onSurfaceVariant),
                      prefixIcon: Icon(Icons.email_outlined, color: YomuColors.onSurfaceVariant),
                      filled: true,
                      fillColor: YomuColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: YomuColors.primary, width: 2),
                      ),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? loc.translate('auth_invalid_email') : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _authenticate(),
                    style: TextStyle(color: YomuColors.onSurface),
                    decoration: InputDecoration(
                      labelText: loc.translate('auth_password'),
                      labelStyle: TextStyle(color: YomuColors.onSurfaceVariant),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: YomuColors.onSurfaceVariant),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: YomuColors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: YomuColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: YomuColors.primary, width: 2),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? loc.translate('auth_min_chars') : null,
                  ),
                  
                  const SizedBox(height: 8),

                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          loc.translate('auth_forgot_password'),
                          style: TextStyle(
                            color: YomuColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 24),

                  const SizedBox(height: 16),

                  if (_isLoading)
                    Center(child: CircularProgressIndicator(color: YomuColors.primary))
                  else
                    FilledButton(
                      onPressed: _authenticate,
                      style: FilledButton.styleFrom(
                        backgroundColor: YomuColors.primary,
                        foregroundColor: YomuColors.onPrimary,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: Text(_isLogin ? loc.translate('auth_sign_in') : loc.translate('auth_sign_up')),
                    ),
                  
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? loc.translate('auth_no_account') : loc.translate('auth_has_account'),
                        style: TextStyle(color: YomuColors.onSurfaceVariant, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(
                          _isLogin ? loc.translate('auth_sign_up') : loc.translate('auth_sign_in'),
                          style: TextStyle(
                            color: YomuColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}