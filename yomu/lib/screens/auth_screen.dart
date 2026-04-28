import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import '../yomu_colors.dart';

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

  // ─── Logic ────────────────────────────────────────────────────
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (mounted) {
        // Pulisce tutta la cronologia di navigazione e forza l'apertura del MainScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _showError('Errore registrazione: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (mounted) {
        // Pulisce tutta la cronologia di navigazione e forza l'apertura del MainScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) _showError('Credenziali errate o inesistenti.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: YomuColors.onSurface, fontSize: 13),
        ),
        backgroundColor: YomuColors.error.withOpacity(0.15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 0,
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: YomuColors.onSurfaceVariant,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: YomuColors.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: YomuColors.surfaceContainerHigh,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: YomuColors.outlineVariant.withOpacity(0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: YomuColors.onPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: YomuColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: YomuColors.error, width: 1.5),
      ),
      errorStyle: const TextStyle(color: YomuColors.error, fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YomuColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: YomuColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: YomuColors.onSurface,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ──
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: YomuColors.primary.withOpacity(0.12),
                      border: Border.all(
                        color: YomuColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: YomuColors.primary,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Headline ──
                const Text(
                  'Bentornato',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: YomuColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Accedi per salvare i tuoi manga e i progressi di lettura.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: YomuColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Email ──
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    color: YomuColors.onSurface,
                    fontSize: 14,
                  ),
                  decoration: _fieldDecoration(
                    'Email',
                    Icons.mail_outline_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Inserisci un\'email';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Formato email non valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Password ──
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                    color: YomuColors.onSurface,
                    fontSize: 14,
                  ),
                  decoration:
                      _fieldDecoration(
                        'Password',
                        Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: YomuColors.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Inserisci una password';
                    if (v.length < 6) {
                      return 'La password deve avere almeno 6 caratteri';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── Buttons ──
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: YomuColors.primary,
                    ),
                  )
                else ...[
                  FilledButton(
                    onPressed: _signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: YomuColors.primary,
                      foregroundColor: YomuColors.onPrimary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    child: const Text('Accedi'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _signUp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: YomuColors.primary,
                      side: BorderSide(
                        color: YomuColors.primary.withOpacity(0.4),
                      ),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    child: const Text('Non hai un account? Registrati'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
