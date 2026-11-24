import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'state.dart';

/// "Use the app without an account": everything stays on this device, nothing is synced.
/// Lets you keep working even if the cloud service is unavailable.
class OfflineMode {
  static final ValueNotifier<bool> on = ValueNotifier<bool>(false);
  static const _key = 'bosalty_offline';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      on.value = p.getBool(_key) ?? false;
    } catch (_) {}
  }

  static Future<void> set(bool v) async {
    on.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, v);
    } catch (_) {}
  }
}

/// Shows the login screen until there is a valid session (or offline mode is on), then shows [child].
/// The session is stored on the device, so you only sign in once.
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    GoTrueClient? auth;
    try {
      auth = Supabase.instance.client.auth;
    } catch (_) {}
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineMode.on,
      builder: (context, offline, _) {
        Widget gate(Session? session) {
          // signed in for real: leave offline mode so a later sign-out goes back to the login screen
          if (session != null && offline) {
            WidgetsBinding.instance.addPostFrameCallback((_) => OfflineMode.set(false));
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: (session != null || offline)
                ? KeyedSubtree(key: const ValueKey('app'), child: child)
                : const LoginScreen(key: ValueKey('login')),
          );
        }

        if (auth == null) return gate(null);
        final a = auth;
        return StreamBuilder<AuthState>(
          stream: a.onAuthStateChange,
          builder: (context, snap) => gate(snap.data?.session ?? a.currentSession),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _store = const FlutterSecureStorage();
  bool _hidden = true;
  bool _loading = false;
  bool _remember = true;
  bool _signUp = false; // false = sign in, true = create account
  final _confirm = TextEditingController();
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final remember = await _store.read(key: 'remember');
      final email = await _store.read(key: 'email');
      final pass = await _store.read(key: 'password');
      if (!mounted) return;
      setState(() {
        _remember = remember != 'false';
        if (email != null) _email.text = email;
        if (pass != null) _password.text = pass;
      });
    } catch (_) {}
  }

  Future<void> _saveCredentials() async {
    try {
      if (_remember) {
        await _store.write(key: 'remember', value: 'true');
        await _store.write(key: 'email', value: _email.text.trim());
        await _store.write(key: 'password', value: _password.text);
      } else {
        await _store.write(key: 'remember', value: 'false');
        await _store.delete(key: 'email');
        await _store.delete(key: 'password');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---- clipboard that works with ANY keyboard layout (Arabic included) ----
  // Flutter matches Ctrl+V by the typed letter, so with an Arabic layout the
  // shortcut never fires. We match the physical key instead.
  Future<void> _paste(TextEditingController c) async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = (d?.text ?? '').replaceAll(RegExp(r'[\r\n]+'), '');
    if (t.isEmpty) return;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, t),
      selection: TextSelection.collapsed(offset: start + t.length),
    );
  }

  Future<void> _copy(TextEditingController c, {bool cut = false}) async {
    final sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: sel.textInside(c.text)));
    if (cut) {
      c.value = TextEditingValue(
        text: c.text.replaceRange(sel.start, sel.end, ''),
        selection: TextSelection.collapsed(offset: sel.start),
      );
    }
  }

  KeyEventResult _keys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (!(hw.isControlPressed || hw.isMetaPressed)) return KeyEventResult.ignored;
    final c = _passwordFocus.hasFocus ? _password : (_emailFocus.hasFocus ? _email : null);
    if (c == null) return KeyEventResult.ignored;
    final k = e.physicalKey;
    if (k == PhysicalKeyboardKey.keyV) {
      _paste(c);
    } else if (k == PhysicalKeyboardKey.keyC || k == PhysicalKeyboardKey.keyX) {
      if (!(identical(c, _password) && _hidden)) _copy(c, cut: k == PhysicalKeyboardKey.keyX);
    } else if (k == PhysicalKeyboardKey.keyA) {
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _pasteBtn(TextEditingController c) => IconButton(
        tooltip: 'Paste',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.content_paste_rounded, size: 18, color: AppScope.of(context).pal.muted),
        onPressed: _loading ? null : () => _paste(c),
      );

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_signUp) {
        final res = await auth.signUp(email: _email.text.trim(), password: _password.text);
        if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
          // Supabase hides "already registered" this way when email confirmation is on
          setState(() => _error = 'This email is already registered. Sign in instead.');
        } else if (res.session == null) {
          // the project requires confirming the email first
          setState(() {
            _signUp = false;
            _confirm.clear();
            _info = 'Account created. Check your email to confirm it, then sign in.';
          });
        } else {
          await _saveCredentials();
          // AuthGate switches to the app automatically.
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await _saveCredentials();
        // AuthGate switches to the app automatically.
      }
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      setState(() {
        if (m.contains('already')) {
          _error = 'This email is already registered. Sign in instead.';
        } else if (!_signUp && m.contains('invalid')) {
          _error = 'Email or password is incorrect.';
        } else if (_signUp && m.contains('invalid') && m.contains('email')) {
          _error = 'Enter a valid email address.';
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      setState(() => _error = "Can't reach the server. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    InputDecoration deco(String label, IconData icon, {Widget? suffix}) {
      OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c, width: w),
          );
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: p.muted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: border(p.muted.withOpacity(0.25)),
        focusedBorder: border(p.accent, 1.6),
        errorBorder: border(cs.error),
        focusedErrorBorder: border(cs.error, 1.6),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _keys,
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/brand/seal.png', width: 170, height: 170),
                  const SizedBox(height: 20),
                  Text(AppScope.of(context).t('brand'),
                      style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text(_signUp
                      ? 'Create an account to sync your tasks and goals.'
                      : 'Sign in to sync your tasks and goals.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: p.muted)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.muted.withOpacity(0.15)),
                    ),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _email,
                              focusNode: _emailFocus,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              enabled: !_loading,
                              decoration: deco('Email', Icons.mail_outline_rounded, suffix: _pasteBtn(_email)),
                              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                              validator: (v) {
                                final s = v?.trim() ?? '';
                                if (s.isEmpty) return 'Enter your email.';
                                if (!s.contains('@') || !s.contains('.')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              focusNode: _passwordFocus,
                              obscureText: _hidden,
                              autofillHints: const [AutofillHints.password],
                              enabled: !_loading,
                              decoration: deco(
                                'Password',
                                Icons.lock_outline_rounded,
                                suffix: Row(mainAxisSize: MainAxisSize.min, children: [
                                  _pasteBtn(_password),
                                  IconButton(
                                  tooltip: _hidden ? 'Show password' : 'Hide password',
                                  icon: Icon(
                                    _hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: p.muted,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _hidden = !_hidden),
                                  ),
                                ]),
                              ),
                              textInputAction: _signUp ? TextInputAction.next : TextInputAction.done,
                              onFieldSubmitted: (_) => _signUp ? null : _submit(),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter your password.';
                                if (_signUp && v.length < 6) return 'Use at least 6 characters.';
                                return null;
                              },
                            ),
                            if (_signUp) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirm,
                                obscureText: _hidden,
                                textInputAction: TextInputAction.done,
                                enabled: !_loading,
                                decoration: deco('Confirm password', Icons.lock_outline_rounded),
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) =>
                                    v != _password.text ? 'Passwords do not match.' : null,
                              ),
                            ],
                            const SizedBox(height: 6),
                            CheckboxListTile(
                              value: _remember,
                              onChanged: _loading ? null : (v) => setState(() => _remember = v ?? true),
                              title: const Text('Remember me'),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: p.accent,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.topCenter,
                              child: _error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: cs.error.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.error_outline_rounded,
                                                size: 18, color: cs.error),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(_error!,
                                                  style: text.bodySmall
                                                      ?.copyWith(color: cs.error)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            if (_info != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: p.accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.mark_email_read_outlined, size: 18, color: p.accent),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_info!,
                                            style: text.bodySmall?.copyWith(color: p.accent)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.4, color: Colors.white),
                                      )
                                    : Text(_signUp ? 'Create account' : 'Sign in',
                                        style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() {
                                        _signUp = !_signUp;
                                        _error = null;
                                        _info = null;
                                        _confirm.clear();
                                      }),
                              child: Text(
                                _signUp
                                    ? 'Already have an account? Sign in'
                                    : "Don't have an account? Sign up",
                                style: TextStyle(color: p.accent, fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _loading ? null : () => OfflineMode.set(true),
                              icon: Icon(Icons.cloud_off_rounded, size: 18, color: p.muted),
                              label: Text('Continue without an account (data stays on this device)',
                                  textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Your tasks and goals stay private to your account.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: p.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
