import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notify.dart';
import 'state.dart';
import 'ui.dart';

/// One tone the user can pick for the end of a focus session.
class TimerSound {
  const TimerSound(this.id, this.ar, this.en);
  final String id, ar, en;

  /// 'system' = the phone's own default notification sound (no file).
  bool get isSystem => id == 'system';

  /// 'custom' = the file the user picked on this device.
  bool get isCustom => id == 'custom';

  /// Path for audioplayers (relative to the assets/ folder).
  String get asset => 'sounds/timer_$id.wav';
}

class TimerSounds {
  static const defaultId = 'chime';
  static const customId = 'custom';

  static const _builtIn = [
    TimerSound('chime', 'رنّة رقيقة', 'Soft chime'),
    TimerSound('bell', 'جرس', 'Bell'),
    TimerSound('marimba', 'ماريمبا', 'Marimba'),
    TimerSound('digital', 'منبّه رقمي', 'Digital alarm'),
    TimerSound('calm', 'هادئة', 'Calm'),
    TimerSound('bowl', 'طاسة تأمّل', 'Singing bowl'),
    TimerSound('system', 'صوت النظام الافتراضي', 'System default'),
  ];

  /// The built-in tones, then the user's own file (only if there is one on this device).
  static List<TimerSound> get all => [..._builtIn, if (hasCustom) _custom()];

  static TimerSound _custom() => TimerSound(customId, customName, customName);

  static TimerSound? byId(String? id) {
    if (id == customId) return hasCustom ? _custom() : null;
    for (final s in _builtIn) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------- the user's own file (this device only)

  static const customExt = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'];
  static const maxCustomBytes = 20 * 1024 * 1024;
  static const _kPath = 'bosalty_custom_sound';
  static const _kName = 'bosalty_custom_sound_name';

  static String? customPath;
  static String customName = '';
  static bool get hasCustom => customPath != null;

  /// Call once at start-up (AppState.load does).
  static Future<void> loadCustom() async {
    try {
      if (kIsWeb) return;
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kPath);
      if (path != null && File(path).existsSync()) {
        customPath = path;
        customName = prefs.getString(_kName) ?? '';
      }
    } catch (e) {
      debugPrint('TimerSounds.loadCustom error: $e');
    }
  }

  /// Lets the user pick an audio file and keeps a copy inside the app.
  /// Returns 'ok', 'cancel', 'big' (over 20 MB) or 'error'.
  static Future<String> pickCustom() async {
    if (kIsWeb) return 'error';
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: customExt);
      if (files.isEmpty) return 'cancel';
      final f = files.first;
      final bytes = await f.readAsBytes();
      if (bytes.length > maxCustomBytes) return 'big';

      final dot = f.name.lastIndexOf('.');
      final raw = dot >= 0 ? f.name.substring(dot + 1).toLowerCase() : 'mp3';
      final ext = customExt.contains(raw) ? raw : 'mp3';

      final dir = await getApplicationSupportDirectory();
      await stop();
      // a new file name every time, so a file that is still open (Windows) never blocks the replace
      final dest = File('${dir.path}${Platform.pathSeparator}custom_timer_sound_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await dest.writeAsBytes(bytes, flush: true);

      final old = customPath;
      customPath = dest.path;
      customName = f.name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPath, dest.path);
      await prefs.setString(_kName, f.name);
      if (old != null) {
        try {
          await File(old).delete();
        } catch (_) {}
      }
      return 'ok';
    } catch (e) {
      debugPrint('TimerSounds.pickCustom error: $e');
      return 'error';
    }
  }

  static Future<void> removeCustom() async {
    await stop();
    final old = customPath;
    customPath = null;
    customName = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPath);
      await prefs.remove(_kName);
      if (old != null) await File(old).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- playing

  static AudioPlayer? _player;
  static bool _ctxSet = false;

  /// The id of the tone that is playing right now (null = nothing). The settings sheet listens to it.
  static final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  /// Plays a tone inside the app (preview in settings, and the finish sound on Windows / phone with the app open).
  static Future<void> play(String id) async {
    try {
      final s = byId(id) ?? byId(defaultId)!;
      if (s.isSystem) {
        playing.value = null;
        await SystemSound.play(SystemSoundType.alert);
        return;
      }
      var p = _player;
      if (p == null) {
        p = AudioPlayer();
        p.onPlayerComplete.listen((_) => playing.value = null);
        _player = p;
      }
      if (!_ctxSet) {
        _ctxSet = true;
        // lower the Quran radio for a moment instead of stopping it
        await p.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build());
      }
      await p.stop();
      if (s.isCustom) {
        await p.play(DeviceFileSource(customPath!));
      } else {
        await p.play(AssetSource(s.asset));
      }
      playing.value = s.id;
    } catch (e) {
      playing.value = null;
      debugPrint('TimerSounds.play error: $e');
    }
  }

  static Future<void> stop() async {
    playing.value = null;
    try {
      await _player?.stop();
    } catch (_) {}
  }
}

// ==================================================================== settings sheet

/// Opens the list of tones: tap a row to choose it, tap ▶ to listen first, or add a file of your own.
Future<void> showTimerSoundSheet(BuildContext context) {
  final s = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: s.pal.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => AppScope(state: s, child: const TimerSoundSheet()),
  ).whenComplete(TimerSounds.stop);
}

class TimerSoundSheet extends StatefulWidget {
  const TimerSoundSheet({super.key});
  @override
  State<TimerSoundSheet> createState() => _TimerSoundSheetState();
}

class _TimerSoundSheetState extends State<TimerSoundSheet> {
  bool _busy = false;

  String _l(AppState s, String ar, String en) => s.rtl ? ar : en;

  Future<void> _pick(AppState s) async {
    setState(() => _busy = true);
    final r = await TimerSounds.pickCustom();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == 'ok') {
      s.setTimerSound(TimerSounds.customId);
      TimerSounds.play(TimerSounds.customId);
    } else if (r == 'big') {
      s.toast(_l(s, 'الملف كبير: الحد الأقصى 20 ميجا', 'File too big: 20 MB at most'));
    } else if (r == 'error') {
      s.toast(_l(s, 'ما قدرتش أفتح الملف ده', "Couldn't use that file"));
    }
  }

  Future<void> _remove(AppState s) async {
    final wasSelected = s.timerSoundId == TimerSounds.customId;
    await TimerSounds.removeCustom();
    if (!mounted) return;
    if (wasSelected) s.setTimerSound(TimerSounds.defaultId);
    setState(() {});
  }

  Widget _row(AppState s, TimerSound o, String cur) {
    final p = s.pal;
    final on = o.id == cur;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(
        on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: on ? p.accent : p.muted,
      ),
      title: Txt(s.rtl ? o.ar : o.en, size: 14, bold: on, color: on ? p.accent : null, maxLines: 1),
      subtitle: o.isCustom ? Txt(_l(s, 'ملفك', 'Your file'), size: 12, color: p.muted) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (o.isCustom)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _l(s, 'حذف', 'Delete'),
            onPressed: () => _remove(s),
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: kUrgent),
          ),
        ValueListenableBuilder<String?>(
          valueListenable: TimerSounds.playing,
          builder: (_, now, __) => IconButton(
            tooltip: _l(s, 'اسمع', 'Listen'),
            onPressed: () => now == o.id ? TimerSounds.stop() : TimerSounds.play(o.id),
            icon: Icon(
              now == o.id ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
              color: p.accent,
              size: 30,
            ),
          ),
        ),
      ]),
      onTap: () => s.setTimerSound(o.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final cur = s.timerSoundId;
    final rows = TimerSounds.all;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: p.muted.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 6),
            Expanded(child: Txt(_l(s, 'رنّة نهاية الجلسة', 'Session end tone'), size: 20, bold: true, head: true)),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: p.muted)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Txt(
              _l(s, 'اضغط ▶ تسمعها، واضغط على الاسم تختارها.', 'Tap ▶ to listen, tap the name to choose it.'),
              size: 12,
              color: p.muted,
            ),
          ),
          Material(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: p.muted.withOpacity(0.12)),
                _row(s, rows[i], cur),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Material(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: p.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                child: _busy
                    ? Padding(padding: const EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2.5, color: p.accent))
                    : Icon(Icons.library_music_rounded, size: 20, color: p.accent),
              ),
              title: Txt(
                TimerSounds.hasCustom ? _l(s, 'استبدال بملف تاني', 'Replace with another file') : _l(s, 'اختار ملف من عندك', 'Choose a file from your device'),
                size: 14,
                bold: true,
                color: p.accent,
              ),
              subtitle: Txt('mp3 · wav · ogg · m4a · aac · flac', size: 12, color: p.muted),
              onTap: _busy ? null : () => _pick(s),
            ),
          ),
          if (Notify.supported)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Txt(
                _l(s, 'ملفك بيرن لما التطبيق يكون مفتوح. لو التطبيق في الخلفية بيرن بالرنة الرقيقة.',
                    'Your file rings while the app is open. In the background the soft chime rings instead.'),
                size: 12,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }
}
