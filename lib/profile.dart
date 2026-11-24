import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';
import 'state.dart';
import 'ui.dart';

/// "App" block at the bottom of Settings: name, what I'm focusing on, account and sign out.
/// (The separate profile screen / header icon were removed: everything lives in Settings now.)
class AppSection extends StatefulWidget {
  const AppSection({super.key});
  @override
  State<AppSection> createState() => _AppSectionState();
}

class _AppSectionState extends State<AppSection> {
  AppState? _s;
  late final TextEditingController _name;
  final _focusCtl = TextEditingController();
  late List<String> _focus;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s == null) {
      _s = AppScope.of(context);
      final pr = _s!.profile;
      _name = TextEditingController(text: '${pr['name'] ?? ''}');
      _focus = ((pr['focus'] ?? const []) as List).map((e) => '$e').toList();
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      // Save without notifying listeners (we are being removed from the tree).
      _s!.data['profile'] = {'name': _name.text.trim(), 'focus': _focus};
      _s!.save();
    }
    _name.dispose();
    _focusCtl.dispose();
    super.dispose();
  }

  void _commitSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _commitNow);
  }

  void _commitNow() {
    _debounce?.cancel();
    _s!.setProfile(_name.text.trim(), List<String>.from(_focus));
  }

  void _addFocus() {
    final t = _focusCtl.text.trim();
    if (t.isEmpty) return;
    if (!_focus.contains(t)) setState(() => _focus.add(t));
    _focusCtl.clear();
    _commitNow();
  }

  void _removeFocus(String t) {
    setState(() => _focus.remove(t));
    _commitNow();
  }

  Future<void> _signOut() async {
    final s = _s!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('prof_signout_q')),
        content: Text(s.t('prof_signout_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('prof_cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Colors.white),
            child: Text(s.t('prof_signout')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _commitNow();
    // Close the settings sheet, then sign out: the login screen appears by itself.
    Navigator.of(context).popUntil((r) => r.isFirst);
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final cs = Theme.of(context).colorScheme;
    String? email;
    try {
      email = Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {}
    final offline = OfflineMode.on.value && email == null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (email != null) ...[
        Txt(email, size: 12, color: p.muted),
        const SizedBox(height: 12),
      ],
      Txt(s.t('prof_name'), size: 13, bold: true),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        style: TextStyle(color: p.text),
        textInputAction: TextInputAction.done,
        decoration: fieldDeco(p, s.t('prof_name_ph')),
        onChanged: (_) => _commitSoon(),
      ),
      const SizedBox(height: 16),
      Txt(s.t('prof_focus'), size: 13, bold: true),
      const SizedBox(height: 10),
      if (_focus.isEmpty)
        Txt(s.t('prof_focus_empty'), size: 12, color: p.muted)
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in _focus)
            InputChip(
              label: Text(f),
              labelStyle: TextStyle(color: p.text),
              backgroundColor: p.sel,
              side: BorderSide.none,
              deleteIconColor: p.muted,
              onDeleted: () => _removeFocus(f),
            ),
        ]),
      const SizedBox(height: 12),
      TextField(
        controller: _focusCtl,
        style: TextStyle(color: p.text),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _addFocus(),
        decoration: fieldDeco(p, s.t('prof_focus_ph')).copyWith(
          suffixIcon: IconButton(
            onPressed: _addFocus,
            icon: Icon(Icons.add_circle_rounded, color: p.accent),
          ),
        ),
      ),
      const SizedBox(height: 22),
      if (offline) ...[
        Txt(s.rtl ? 'أنت تستخدم التطبيق بدون حساب. بياناتك على هذا الجهاز فقط ولا تتم مزامنتها.' : 'You are using the app without an account. Your data stays on this device and is not synced.',
            size: 12, color: p.muted),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              OfflineMode.set(false);
            },
            icon: const Icon(Icons.login_rounded),
            label: Text(s.rtl ? 'تسجيل الدخول للمزامنة' : 'Sign in to sync'),
            style: FilledButton.styleFrom(backgroundColor: p.accent),
          ),
        ),
      ] else
      SizedBox(
        height: 50,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _signOut,
          icon: Icon(Icons.logout_rounded, color: cs.error),
          label: Text(s.t('prof_signout'), style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: cs.error.withOpacity(0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }
}
