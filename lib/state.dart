import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'notify.dart';
import 'prayer.dart';
import 'sounds.dart';
import 'strings.dart';
import 'worship_log.dart';

// prayerTimes() / PrayerConfig now live in prayer.dart; other files keep importing them from here.
export 'prayer.dart';

// ---------------- constants ----------------
const projects = ['Dlight', 'Umami', 'Graduation Project', 'Learning', 'Freelance'];
const projectAr = {'Graduation Project': 'منظور', 'Learning': 'التعلّم', 'Freelance': 'العمل الحر'};
const projectEn = {'Graduation Project': 'Manzoor'};
const projectIcon = {
  'Dlight': 'p_dlight', 'Umami': 'p_umami', 'Graduation Project': 'p_manzoor',
  'Learning': 'learning', 'Freelance': 'freelance',
};
const projectTile = {
  'All': 'all', 'Dlight': 'dlight', 'Umami': 'umami',
  'Graduation Project': 'manzoor', 'Learning': 'learning', 'Freelance': 'freelance',
};
// (light, dark)
const projectColors = {
  'Dlight': [Color(0xFF2563EB), Color(0xFF60A5FA)],
  'Umami': [Color(0xFF8B5CF6), Color(0xFFC084FC)],
  'Graduation Project': [Color(0xFFF97316), Color(0xFFFB923C)],
  'Learning': [Color(0xFF0D9488), Color(0xFF2DD4BF)],
  'Freelance': [Color(0xFFD97706), Color(0xFFFBBF24)],
};
const goalTint = {
  'Dlight': [Color(0xFFEFF6FF), Color(0xFF1E2638)],
  'Umami': [Color(0xFFF5F3FF), Color(0xFF272138)],
  'Graduation Project': [Color(0xFFFFF7ED), Color(0xFF38281E)],
  'Learning': [Color(0xFFF0FDFA), Color(0xFF163330)],
  'Freelance': [Color(0xFFFFFBEB), Color(0xFF38311E)],
};
// colours for projects the user creates: (light, dark)
const customPalette = [
  [Color(0xFFDB2777), Color(0xFFF472B6)],
  [Color(0xFF0891B2), Color(0xFF22D3EE)],
  [Color(0xFF65A30D), Color(0xFFA3E635)],
  [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  [Color(0xFFDC2626), Color(0xFFF87171)],
  [Color(0xFF4F46E5), Color(0xFF818CF8)],
  [Color(0xFF0D9488), Color(0xFF5EEAD4)],
  [Color(0xFFCA8A04), Color(0xFFFDE047)],
];
const renames = {'umaime': 'Umami', 'مشروع التخرج': 'Graduation Project', 'Religion': 'Freelance'};
/// Red used for errors, delete buttons and urgent tasks.
const kUrgent = Color(0xFFE11D48);
const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const sections = ['global', 'header', 'tasks', 'timer', 'history', 'goals'];

// accent: [accent light, accent dark, selected light, selected dark]
const accents = {
  'red': [Color(0xFFE11D48), Color(0xFFF43F5E), Color(0xFFFFE4E6), Color(0xFF881337)],
  'teal': [Color(0xFF0D9488), Color(0xFF14B8A6), Color(0xFFCCFBF1), Color(0xFF114B46)],
  'blue': [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFFDBEAFE), Color(0xFF1E3A8A)],
  'purple': [Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFEDE9FE), Color(0xFF4C1D95)],
  'emerald': [Color(0xFF059669), Color(0xFF10B981), Color(0xFFD1FAE5), Color(0xFF064E3B)],
  'orange': [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFFEDD5), Color(0xFF7C2D12)],
};

// ---------------- palette ----------------
class Pal {
  final bool dark;
  final Color accent, sel;
  final Map<String, int> custom; // colour index of the projects the user created
  Pal(this.dark, String accentKey, [this.custom = const {}])
      : accent = accents[accentKey]![dark ? 1 : 0],
        sel = accents[accentKey]![dark ? 3 : 2];
  Color get bg => dark ? const Color(0xFF121112) : const Color(0xFFF9F9FB);
  Color get card => dark ? const Color(0xFF1C1A1B) : Colors.white;
  Color get card2 => dark ? const Color(0xFF262324) : const Color(0xFFF1F3F5);
  Color get hover => dark ? const Color(0xFF363234) : const Color(0xFFE2E8F0);
  Color get text => dark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
  Color get muted => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get track => dark ? const Color(0xFF262325) : const Color(0xFFE2E8F0);
  Color get onProj => dark ? const Color(0xFF141213) : Colors.white;
  Color proj(String p) {
    final c = projectColors[p];
    if (c != null) return c[dark ? 1 : 0];
    final i = custom[p];
    if (i != null) return customPalette[i % customPalette.length][dark ? 1 : 0];
    return accent;
  }

  Color tint(String p) {
    final t = goalTint[p];
    if (t != null) return t[dark ? 1 : 0];
    if (custom.containsKey(p)) return Color.alphaBlend(proj(p).withOpacity(0.12), card2);
    return card2;
  }
}

// ---------------- date helpers ----------------
String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime? parseDate(String? raw) {
  try {
    final d = DateTime.parse((raw ?? '').trim());
    return dateOnly(d);
  } catch (_) {
    return null;
  }
}

// ---------------- settings defaults ----------------
Map<String, dynamic> defaultSettings() => {
      'lang': 'ar', 'theme': 'dark', 'accent': 'red',
      'font_global': 1.0, 'font_header': 1.0, 'font_tasks': 1.0,
      'font_timer': 1.0, 'font_history': 1.0, 'font_goals': 1.0,
      'compact_tasks': false, 'show_tiles': true, 'default_all_days': false,
      'presets': [15, 25, 45, 60],
      'show_prayers': true, 'sound': true, 'notify': true,
      'prayer_alerts': true,
      'city': 'cairo', // prayer-times city (id from prayer.dart, or 'custom' with city_lat / city_lng)
      'adhkar_morning_alert': false,
      'adhkar_evening_alert': false,
      'timer_sound': 'chime',
      'mushaf_font': 28.0,
    };

Map<String, dynamic> defaultData() => {
      'tasks': [], 'sessions': [], 'goals': [],
      'project_meta': {},
      'settings': defaultSettings(),
    };

String newId() {
  final r = math.Random();
  const hex = '0123456789abcdef';
  return List.generate(8, (_) => hex[r.nextInt(16)]).join();
}



// ---------------- app state ----------------
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  Map<String, dynamic> data = defaultData();
  SharedPreferences? _prefs;



  // ui state
  int tab = 0;
  String filter = 'All';
  String histFilter = 'All';
  DateTime day = dateOnly(DateTime.now());
  bool allDays = false;
  DateTime goalMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? selectedId;
  String timerProject = projects[0];

  // toast
  String toastMsg = '';
  int toastSeq = 0;

  // timer
  int total = 25 * 60;
  int remaining = 25 * 60;
  bool running = false;
  Map<String, dynamic>? ctx;
  DateTime? _endAt;
  Timer? _ticker;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    await TimerSounds.loadCustom(); // the user's own tone file (this device only)
    final base = defaultData();
    try {
      final raw = _prefs!.getString('bosalty_data');
      if (raw != null) base.addAll(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
    _normalize(base);
    data = base;
    _applyCity();
    _lastSynced = _prefs?.getString(_syncedKey) ?? '';
    _resetSigs();
    _fixProjectRefs();
    allDays = settings['default_all_days'] == true;
    final p = presets;
    total = (p.length > 1 ? p[1] : p[0]) * 60;
    remaining = total;
    _autoSnapshot();

    // cloud sync: same `app_data` row the desktop app uses
    WidgetsBinding.instance.addObserver(this);
    Supabase.instance.client.auth.onAuthStateChange.listen((e) {
      if (e.session != null &&
          (e.event == AuthChangeEvent.signedIn || e.event == AuthChangeEvent.initialSession)) {
        pullRemote();
        _startRealtime();
      } else if (e.event == AuthChangeEvent.signedOut) {
        _stopRealtime();
      }
    });
    _pullTimer = Timer.periodic(const Duration(seconds: 30), (_) => pullRemote());
    pullRemote();
    _startRealtime();
  }

  void _normalize(Map<String, dynamic> base) {
    base['settings'] = {...defaultSettings(), ...Map<String, dynamic>.from((base['settings'] ?? {}) as Map)};
    for (final t in (base['tasks'] as List)) {
      t['project'] = renames[t['project']] ?? t['project'];
      t['date'] ??= iso(DateTime.now());
      t['goal'] ??= null;
    }
    for (final g in (base['goals'] as List)) {
      g['category'] = renames[g['category']] ?? g['category'];
    }
    for (final x in (base['sessions'] as List)) {
      x['project'] = renames[x['project']] ?? x['project'];
    }
  }

  // ---------------- backup export / import ----------------
  /// Everything in the app (tasks, goals, sessions, settings, profile) as one JSON text.
  String exportBackupJson() {
    final backup = {
      'app': 'bosalty',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': data,
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  static const _safetyKey = 'bosalty_before_restore';
  static const _autoKey = 'bosalty_auto_backups';

  /// Replaces ALL current data with the backup. Returns false (and changes nothing) if the text is not a valid backup.
  /// The data you had right before is kept aside, so a wrong restore can be undone ([undoRestore]).
  bool importBackupJson(String jsonStr, {bool keepSafety = true}) {
    try {
      final decoded = jsonDecode(jsonStr.trim());
      if (decoded is! Map) return false;
      final raw = Map<String, dynamic>.from(decoded);
      final imported = (raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : raw;
      // basic sanity check: must look like Bosalty data
      if (imported['tasks'] is! List && imported['sessions'] is! List && imported['goals'] is! List) return false;

      final base = defaultData();
      base.addAll(imported);
      for (final k in ['tasks', 'goals', 'sessions']) {
        if (base[k] is! List) base[k] = [];
      }
      _normalize(base);

      if (keepSafety) _prefs?.setString(_safetyKey, jsonEncode(data));
      data = base;
      _applyCity();
      // (the item signatures are NOT reset here: save() below then stamps what the restore changed and
      //  records what it removed, so the restore also wins against the cloud copy)
      selectedId = null;
      _fixProjectRefs();
      allDays = settings['default_all_days'] == true;
      save(); // stamps it as newest, so it also replaces the cloud copy
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Backup import error: $e');
      return false;
    }
  }

  /// true while there is a "before the last restore" copy that can be brought back.
  bool get hasUndoRestore => _prefs?.getString(_safetyKey) != null;

  bool undoRestore() {
    final raw = _prefs?.getString(_safetyKey);
    if (raw == null) return false;
    final ok = importBackupJson(raw, keepSafety: false);
    if (ok) _prefs?.remove(_safetyKey);
    return ok;
  }

  // ---- automatic daily copies kept on the device (last 5 days) ----
  List<Map<String, dynamic>> get autoBackups {
    try {
      final raw = _prefs?.getString(_autoKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  void _autoSnapshot() {
    try {
      final today = iso(DateTime.now());
      final list = autoBackups;
      if (list.isNotEmpty && list.first['day'] == today) return;
      if (tasks.isEmpty && sessions.isEmpty && goals.isEmpty) return;
      list.insert(0, {'day': today, 'json': jsonEncode(data)});
      while (list.length > 5) {
        list.removeLast();
      }
      _prefs?.setString(_autoKey, jsonEncode(list));
    } catch (_) {}
  }

  void save() {
    _stampItems();
    data['_updated'] = _nowStamp();
    _prefs?.setString('bosalty_data', jsonEncode(data));
    _schedulePush();
  }

  // ---------------- cloud sync (Supabase table app_data: user_id, data, updated_at) ----------------
  Timer? _pushTimer, _pullTimer;
  bool _pushPending = false;
  String _lastSyncErr = '';
  bool _syncOkShown = false;

  // ---- merge bookkeeping ----
  // Every task / goal / session / adhkar entry carries `_u` (when it was last changed). Deleted ones are
  // remembered in data['_deleted'] (id -> when). When two devices both changed something, the two copies are
  // combined item by item (newest edit wins) instead of the newer file replacing the other one.
  static const _syncedKey = 'bosalty_last_synced';
  static const _mergeLists = ['tasks', 'goals', 'sessions', 'adhkar_log'];
  final Map<String, String> _sigs = {};
  String _lastSynced = ''; // stamp of the data at the last successful sync (upload or download)
  String _remoteSeen = ''; // stamp of the cloud copy as we last saw it
  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  bool _after(String a, String b) => (DateTime.tryParse(a) ?? _epoch).isAfter(DateTime.tryParse(b) ?? _epoch);

  String _sigOf(Map e) {
    final m = Map<String, dynamic>.from(e)..remove('_u');
    return jsonEncode(m);
  }

  /// Remember how every item looks right now (call after the data was replaced by a load / download / merge).
  void _resetSigs() {
    _sigs.clear();
    for (final k in _mergeLists) {
      final l = data[k];
      if (l is! List) continue;
      for (final e in l) {
        if (e is Map && e['id'] != null) _sigs['$k:${e['id']}'] = _sigOf(e);
      }
    }
  }

  Map<String, dynamic> _tombs() {
    final cur = data['_deleted'];
    if (cur is Map<String, dynamic>) return cur;
    final m = cur is Map ? Map<String, dynamic>.from(cur) : <String, dynamic>{};
    data['_deleted'] = m;
    return m;
  }

  /// Called by save(): stamps the items that changed since last time and records the ones that were removed.
  void _stampItems() {
    final now = _nowStamp();
    final seen = <String>{};
    for (final k in _mergeLists) {
      final l = data[k];
      if (l is! List) continue;
      for (final e in l) {
        if (e is! Map || e['id'] == null) continue;
        final key = '$k:${e['id']}';
        seen.add(key);
        final sig = _sigOf(e);
        if (_sigs[key] != sig) {
          e['_u'] = now;
          _sigs[key] = sig;
        }
      }
    }
    final gone = [for (final key in _sigs.keys) if (!seen.contains(key)) key];
    if (gone.isNotEmpty) {
      final del = _tombs();
      for (final key in gone) {
        _sigs.remove(key);
        del[key.substring(key.indexOf(':') + 1)] = now;
      }
    }
  }

  List<Map<String, dynamic>> _maps(Object? l) =>
      l is List ? [for (final e in l) if (e is Map) Map<String, dynamic>.from(e)] : <Map<String, dynamic>>[];

  /// Combines this device's data with the cloud copy. Settings stay this device's own.
  Map<String, dynamic> _mergeData(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localNewer = !_after('${remote['_updated']}', '${local['_updated']}');
    final first = localNewer ? local : remote;
    final second = localNewer ? remote : local;
    final out = <String, dynamic>{...second, ...first}; // plain values (profile, project list...): newest copy wins
    out['settings'] = local['settings'] ?? remote['settings'];

    final tomb = <String, String>{};
    for (final src in [remote['_deleted'], local['_deleted']]) {
      if (src is! Map) continue;
      src.forEach((k, v) {
        final cur = tomb['$k'];
        if (cur == null || _after('$v', cur)) tomb['$k'] = '$v';
      });
    }

    for (final k in _mergeLists) {
      if (local[k] == null && remote[k] == null) continue;
      final byId = <String, Map<String, dynamic>>{};
      final noId = <Map<String, dynamic>>[];
      for (var side = 0; side < 2; side++) {
        for (final e in _maps(side == 0 ? first[k] : second[k])) {
          if (e['id'] == null) {
            if (side == 0) noId.add(e);
            continue;
          }
          final id = '${e['id']}';
          final cur = byId[id];
          if (cur == null || _after('${e['_u'] ?? ''}', '${cur['_u'] ?? ''}')) byId[id] = e;
        }
      }
      final merged = <dynamic>[...noId];
      byId.forEach((id, e) {
        final d = tomb[id];
        if (d != null && !_after('${e['_u'] ?? ''}', d)) return; // deleted after its last edit
        merged.add(e);
      });
      out[k] = merged;
    }

    // Quran pages read: a page counts once a day, so just join both sides.
    if (local['quran_log'] is Map || remote['quran_log'] is Map) {
      final q = <String, dynamic>{};
      for (final src in [remote['quran_log'], local['quran_log']]) {
        if (src is! Map) continue;
        src.forEach((day, list) {
          if (list is! List) return;
          final cur = q.putIfAbsent('$day', () => <dynamic>[]) as List;
          for (final e in list) {
            if (e is! List || e.length < 2) continue;
            if (!cur.any((c) => c is List && c.isNotEmpty && c[0] == e[0])) cur.add(e);
          }
        });
      }
      num minuteOf(Object? e) => e is List && e.length > 1 ? (num.tryParse('${e[1]}') ?? 0) : 0;
      for (final v in q.values) {
        (v as List).sort((a, b) => minuteOf(a).compareTo(minuteOf(b)));
      }
      out['quran_log'] = q;
    }

    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 60));
    tomb.removeWhere((_, v) => (DateTime.tryParse(v) ?? _epoch).isBefore(cutoff));
    out['_deleted'] = tomb;
    out['_updated'] = _nowStamp();
    return out;
  }

  /// Both this device and the cloud changed since the last sync: download the cloud copy and combine.
  /// (The caller uploads the result.)
  Future<void> _mergeFromCloud(SupabaseClient c, String uid) async {
    final rows = await c.from('app_data').select('data').eq('user_id', uid).limit(1);
    if (rows.isEmpty) return;
    final remote = Map<String, dynamic>.from(rows.first['data'] as Map);
    final base = defaultData();
    base.addAll(_mergeData(data, remote));
    _normalize(base);
    data = base;
    _resetSigs();
    _remoteSeen = '${remote['_updated'] ?? ''}';
    _lastSynced = _remoteSeen;
    _prefs?.setString('bosalty_data', jsonEncode(data));
    if (selectedId != null && findTask(selectedId!) == null) selectedId = null;
    _fixProjectRefs();
    notifyListeners();
    toast(rtl ? 'تم دمج التعديلات من أجهزتك ✓' : 'Merged the changes from your devices ✓');
  }

  void _syncFail(Object e) {
    final m = '$e'.replaceAll('\n', ' ');
    final detail = m.length > 150 ? m.substring(0, 150) : m;
    final msg = rtl ? 'خطأ في المزامنة: $detail' : 'Sync error: $detail';
    if (msg != _lastSyncErr) {
      _lastSyncErr = msg;
      toast(msg);
    }
  }

  void _syncOk() {
    if (_lastSyncErr.isNotEmpty || !_syncOkShown) {
      _lastSyncErr = '';
      _syncOkShown = true;
      toast(rtl ? 'المزامنة السحابية شغّالة' : 'Cloud sync is working');
    }
  }

  // same format the desktop app writes: 2026-11-23T11:30:00.123456+00:00
  String _nowStamp() {
    var s = DateTime.now().toUtc().toIso8601String().replaceFirst('Z', '');
    final dot = s.indexOf('.');
    s = dot == -1 ? '$s.000000' : s.padRight(dot + 7, '0');
    return '$s+00:00';
  }

  User? get _user {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _schedulePush() {
    if (_user == null) return;
    _pushPending = true;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 800), pushNow);
  }

  Future<void> pushNow() async {
    _pushTimer?.cancel();
    if (_user == null) return;
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid == null || !_pushPending) return;
    _pushPending = false;
    try {
      // Did another device upload since we last looked? Then combine first, so nothing it did is overwritten.
      final head = await c.from('app_data').select('stamp:data->>_updated').eq('user_id', uid).limit(1);
      if (head.isNotEmpty) {
        final rs = '${head.first['stamp'] ?? ''}';
        if (rs.isNotEmpty && rs != _remoteSeen && _after(rs, _lastSynced)) {
          await _mergeFromCloud(c, uid);
        }
      }
      final stamp = '${data['_updated']}';
      await c.from('app_data').upsert({
        'user_id': uid,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      _lastSynced = stamp;
      _remoteSeen = stamp;
      _prefs?.setString(_syncedKey, stamp);
      _syncOk();
    } catch (e) {
      _pushPending = true; // try again on the next save / resume
      _syncFail(e);
    }
  }

  bool _pulling = false;
  bool _pullAgain = false;
  RealtimeChannel? _rt;

  /// Listens for changes of this user's row, so an edit made on another device shows up
  /// within a second or two instead of waiting for the 30-second check.
  /// (needs Realtime enabled for the app_data table in Supabase)
  void _startRealtime() {
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    _stopRealtime();
    try {
      _rt = c
          .channel('app_data_$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_data',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
            callback: (_) => pullRemote(),
          )
          .subscribe();
    } catch (_) {}
  }

  void _stopRealtime() {
    final ch = _rt;
    _rt = null;
    if (ch != null) {
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
  }

  Future<void> pullRemote() async {
    if (_user == null) return;
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid == null || running) return;
    if (_pulling) {
      _pullAgain = true; // something changed while we were busy: check once more afterwards
      return;
    }
    if (_pushPending) {
      await pushNow(); // an earlier upload failed (or is waiting): do it first
      return;
    }
    _pulling = true;
    try {
      // 1) tiny request: only the cloud copy's timestamp (a few bytes instead of all the data)
      final head = await c.from('app_data').select('stamp:data->>_updated').eq('user_id', uid).limit(1);
      _syncOk();
      if (head.isEmpty) {
        _pushPending = true; // nothing in the cloud yet: upload this device's data
        await pushNow();
        toast(rtl ? 'السحابة كانت فاضية: اترفعت ${tasks.length} مهمة' : 'Cloud was empty: uploaded ${tasks.length} tasks');
        return;
      }
      final rs = '${head.first['stamp'] ?? ''}';
      _remoteSeen = rs;
      // What changed since the last time both sides were the same?
      final remoteChanged = _after(rs, _lastSynced);
      final localChanged = _after('${data['_updated'] ?? ''}', _lastSynced);
      if (remoteChanged && localChanged) {
        // 2a) both changed: combine them, then upload the result
        await _mergeFromCloud(c, uid);
        _pushPending = true;
        await pushNow();
      } else if (remoteChanged) {
        // 2b) only the cloud changed: download it
        final rows = await c.from('app_data').select('data').eq('user_id', uid).limit(1);
        if (rows.isEmpty) return;
        final remote = Map<String, dynamic>.from(rows.first['data'] as Map);
        final base = defaultData();
        base.addAll(remote);
        base['settings'] = settings; // theme / language / layout / city stay per device
        _normalize(base);
        data = base;
        _resetSigs();
        _lastSynced = rs;
        _prefs?.setString(_syncedKey, rs);
        _prefs?.setString('bosalty_data', jsonEncode(data));
        if (selectedId != null && findTask(selectedId!) == null) selectedId = null;
        _fixProjectRefs();
        notifyListeners();
        toast(rtl ? 'تم تحميل ${tasks.length} مهمة من السحابة' : 'Loaded ${tasks.length} tasks from the cloud');
      } else if (localChanged) {
        // 2c) only this device changed: upload
        _pushPending = true;
        await pushNow();
        toast(rtl ? 'بيانات هذا الجهاز أحدث: اترفعت ${tasks.length} مهمة' : 'This device is newer: uploaded ${tasks.length} tasks');
      }
    } catch (e) {
      _syncFail(e);
    } finally {
      _pulling = false;
      if (_pullAgain) {
        _pullAgain = false;
        pullRemote();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) {
      pullRemote();
    } else if (st == AppLifecycleState.paused || st == AppLifecycleState.detached) {
      pushNow();
    }
  }

  // --- profile (name + what the user is focusing on) ---
  Map<String, dynamic> get profile =>
      Map<String, dynamic>.from((data['profile'] ?? const {}) as Map);

  void setProfile(String name, List<String> focus) {
    data['profile'] = {'name': name, 'focus': focus};
    save();
    notifyListeners();
  }

  // --- accessors ---
  Map<String, dynamic> get settings => data['settings'] as Map<String, dynamic>;
  List<Map<String, dynamic>> get tasks => (data['tasks'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get goals => (data['goals'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get sessions => (data['sessions'] as List).cast<Map<String, dynamic>>();
  String get lang => settings['lang'] as String;
  bool get rtl => lang == 'ar';
  bool get dark => settings['theme'] == 'dark';
  Pal get pal => Pal(dark, settings['accent'] as String, _customColors());
  Locale get locale => Locale(lang);
  List<int> get presets {
    final l = ((settings['presets'] ?? [15, 25, 45, 60]) as List).map((e) => (e as num).toInt()).toList();
    return l.isEmpty ? [25] : l;
  }

  double fs(double size, [String sec = 'global']) {
    final m = (settings['font_$sec'] as num?)?.toDouble() ?? 1.0;
    return math.max(9, (size * m).roundToDouble());
  }

  String t(String key, [Map<String, Object?> p = const {}]) {
    var s = kStr[lang]![key] ?? kStr['en']![key] ?? key;
    p.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  // ---------------- projects: the list + customization (name / line under it / picture) ----------------
  // Every project has an internal key. The built-in ones ('Dlight', 'Umami', ...) keep their keys, new ones
  // get 'c_xxxxxxxx'. Tasks, goals and sessions store that key, so renaming or deleting never breaks old data.
  // The list and the customization live inside `data`: they sync with the cloud and are part of backups.

  /// The projects the user has now, in order.
  List<String> get projectKeys {
    final l = data['project_list'];
    if (l is List) {
      final k = <String>[for (final e in l) if (e is String) e];
      if (k.isNotEmpty) return k;
    }
    return List<String>.of(projects);
  }

  /// [projectKeys] plus [extra] when it is not in the list (a deleted project that an old task still points to),
  /// so a drop-down never gets a value it has no item for.
  List<String> projectKeysWith(String? extra) {
    final k = projectKeys;
    if (extra != null && extra != 'All' && !k.contains(extra)) k.add(extra);
    return k;
  }

  bool isCustomProject(String k) => !projects.contains(k);

  /// Colour index of every project the user created (used by [Pal]).
  Map<String, int> _customColors() {
    final out = <String, int>{};
    final all = data['project_meta'];
    if (all is Map) {
      all.forEach((k, v) {
        if (v is Map && v['ci'] is num) out['$k'] = (v['ci'] as num).toInt();
      });
    }
    return out;
  }

  /// What the user customized for [k]: {name, sub, image(base64 png), noimg, ci}. Empty if nothing.
  Map<String, dynamic> projectMeta(String k) {
    final all = data['project_meta'];
    if (all is Map && all[k] is Map) return Map<String, dynamic>.from(all[k] as Map);
    return <String, dynamic>{};
  }

  /// The built-in name (before any customization).
  String defaultProjectName(String k) => lang == 'ar' ? (projectAr[k] ?? k) : (projectEn[k] ?? k);

  /// The name shown everywhere (tiles, task picker, timer, history, goals, report).
  String pdisp(String k) {
    if (k == 'All') return t('all');
    final v = projectMeta(k)['name'];
    final custom = v is String ? v.trim() : '';
    return custom.isNotEmpty ? custom : defaultProjectName(k);
  }

  /// The small line under the name (e.g. "شركة ديلايت"). Empty if none.
  String psub(String k) {
    final v = projectMeta(k)['sub'];
    return v is String ? v.trim() : '';
  }

  final Map<String, String> _imgSrc = {};
  final Map<String, Uint8List> _imgBytes = {};

  /// The picture the user chose for [k] (null = none). Decoded once and cached.
  Uint8List? pimage(String k) {
    final v = projectMeta(k)['image'];
    final b64 = v is String ? v : '';
    if (b64.isEmpty) {
      _imgSrc.remove(k);
      _imgBytes.remove(k);
      return null;
    }
    if (_imgSrc[k] != b64) {
      try {
        _imgBytes[k] = base64Decode(b64);
        _imgSrc[k] = b64;
      } catch (_) {
        return null;
      }
    }
    return _imgBytes[k];
  }

  /// The user removed the built-in picture of [k] (so its name is written as text).
  bool pNoImage(String k) => projectMeta(k)['noimg'] == true;

  /// [k] has a built-in picture and the user did not remove it.
  bool pHasBuiltin(String k) => projectTile.containsKey(k) && !pNoImage(k);

  /// Does [k] have any picture / icon? If not, its name is written as text instead.
  bool pHasIcon(String k) => pimage(k) != null || pHasBuiltin(k);

  /// Saves the customization of one project. Empty values mean "default".
  void setProjectMeta(String k, {String name = '', String sub = '', String image = '', bool noImage = false}) {
    final all = data['project_meta'] is Map
        ? Map<String, dynamic>.from(data['project_meta'] as Map)
        : <String, dynamic>{};
    final old = projectMeta(k);
    final m = <String, dynamic>{};
    if (old['ci'] is num) m['ci'] = old['ci']; // colour of a project the user created
    if (name.trim().isNotEmpty) m['name'] = name.trim();
    if (sub.trim().isNotEmpty) m['sub'] = sub.trim();
    if (image.isNotEmpty) m['image'] = image;
    if (noImage && image.isEmpty) m['noimg'] = true;
    if (m.isEmpty) {
      all.remove(k);
    } else {
      all[k] = m;
    }
    data['project_meta'] = all;
    _commit();
  }

  /// Back to the built-in name / line / picture (built-in projects only).
  void resetProjectMeta(String k) => setProjectMeta(k);

  /// Adds a new project and returns its key.
  String addProject({required String name, String sub = '', String image = ''}) {
    final id = 'c_${newId()}';
    final keys = projectKeys..add(id);
    data['project_list'] = keys;
    final all = data['project_meta'] is Map
        ? Map<String, dynamic>.from(data['project_meta'] as Map)
        : <String, dynamic>{};
    final used = all.values.where((v) => v is Map && v['ci'] is num).length;
    final m = <String, dynamic>{'ci': used, 'name': name.trim()};
    if (sub.trim().isNotEmpty) m['sub'] = sub.trim();
    if (image.isNotEmpty) m['image'] = image;
    all[id] = m;
    data['project_meta'] = all;
    _commit();
    return id;
  }

  /// Removes a project from the lists. Tasks, goals and sessions that used it are kept (and still show its
  /// name), so nothing is lost. Returns false if it cannot be removed right now.
  bool deleteProject(String k) {
    final keys = projectKeys;
    if (!keys.contains(k)) return false;
    if (keys.length <= 1) {
      toast(rtl ? 'لازم يفضل تصنيف واحد على الأقل' : 'At least one project must stay');
      return false;
    }
    if (ctx != null) {
      toast(t('finish_first'));
      return false;
    }
    keys.remove(k);
    data['project_list'] = keys;
    if (filter == k) filter = 'All';
    if (histFilter == k) histFilter = 'All';
    if (timerProject == k) timerProject = keys.first;
    final sel = findTask(selectedId);
    if (sel != null && sel['project'] == k) selectedId = null;
    _commit();
    return true;
  }

  /// true if some built-in project was deleted.
  bool get hasRemovedDefaults {
    final k = projectKeys;
    return projects.any((e) => !k.contains(e));
  }

  /// Brings back the built-in projects that were deleted.
  void restoreProjects() {
    final keys = projectKeys;
    for (final e in projects) {
      if (!keys.contains(e)) keys.add(e);
    }
    data['project_list'] = keys;
    _commit();
  }

  /// After the data was replaced (start-up, cloud, restore): no filter / timer may point to a missing project.
  void _fixProjectRefs() {
    final k = projectKeys;
    if (filter != 'All' && !k.contains(filter)) filter = 'All';
    if (histFilter != 'All' && !k.contains(histFilter)) histFilter = 'All';
    if (ctx == null && selectedId == null && !k.contains(timerProject)) timerProject = k.first;
  }

  String fmtMin(num m) {
    final h = m.toInt() ~/ 60, mm = m.toInt() % 60;
    return h > 0 ? '$h${t('h')} ${mm.toString().padLeft(2, '0')}${t('m')}' : '$mm${t('m')}';
  }

  String fmtClock(double hours) {
    final minutes = (hours * 60).round() % 1440;
    final hh = minutes ~/ 60, mm = minutes % 60;
    final ap = rtl ? (hh < 12 ? 'ص' : 'م') : (hh < 12 ? 'AM' : 'PM');
    return '${hh % 12 == 0 ? 12 : hh % 12}:${mm.toString().padLeft(2, '0')} $ap';
  }

  String monthName(int m) => kMonths[lang]![m - 1];

  String dateLabel(DateTime d) {
    final wd = kWeekdays[lang]![d.weekday - 1];
    var mo = kMonths[lang]![d.month - 1];
    if (lang == 'en') mo = mo.substring(0, 3);
    return '$wd, ${d.day} $mo ${d.year}';
  }

  List<Map<String, dynamic>> get pendingTasks => tasks.where((x) => x['done'] != true).toList();
  Map<String, dynamic>? findTask(String? id) {
    if (id == null) return null;
    for (final x in tasks) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  // --- toast / refresh ---
  void toast(String msg) {
    toastMsg = msg;
    toastSeq++;
    notifyListeners();
  }

  void _commit() {
    save();
    notifyListeners();
  }

  /// Saves on this device only (no cloud upload): for per-device things such as
  /// theme, language and text sizes, which are never taken from the cloud anyway.
  void _commitLocal() {
    _prefs?.setString('bosalty_data', jsonEncode(data));
    notifyListeners();
  }

  // --- settings / ui ---
  bool get locked => ctx != null;

  bool setSetting(String key, Object? value, {bool needsUnlocked = false}) {
    if (needsUnlocked && locked) {
      toast(t('finish_first'));
      return false;
    }
    settings[key] = value;
    if (key == 'city' || key == 'city_lat' || key == 'city_lng') _applyCity();
    _commitLocal();
    return true;
  }

  // ---------------- prayer-times city ----------------
  void _applyCity() => PrayerConfig.apply(settings['city'] as String?, settings['city_lat'] as num?, settings['city_lng'] as num?);

  /// "Cairo · Egyptian Authority" (shown in Settings).
  String get cityLabel => '${rtl ? PrayerConfig.city.ar : PrayerConfig.city.en} · ${PrayerConfig.methodLabel(rtl)}';

  void setCity(String id) => setSetting('city', id);

  void setCustomCity(double lat, double lng) {
    settings['city_lat'] = lat;
    settings['city_lng'] = lng;
    setSetting('city', PrayerConfig.customId);
  }

  /// The chosen end-of-session tone (falls back to the default if the saved id is unknown).
  String get timerSoundId {
    final id = settings['timer_sound'];
    return (id is String && TimerSounds.byId(id) != null) ? id : TimerSounds.defaultId;
  }

  void setTimerSound(String id) {
    if (TimerSounds.byId(id) == null) return;
    setSetting('timer_sound', id);
    if (running) _scheduleTimerAlert(); // changed while a session is running: re-arm with the new tone
  }

  void toggleTheme() => setSetting('theme', dark ? 'light' : 'dark');
  void toggleLang() => setSetting('lang', rtl ? 'en' : 'ar', needsUnlocked: true);

  void resetSettings() {
    if (locked) {
      toast(t('finish_first'));
      return;
    }
    data['settings'] = defaultSettings();
    _applyCity();
    allDays = false;
    _commitLocal();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void setFilter(String f) {
    filter = f;
    notifyListeners();
  }

  void setHistFilter(String f) {
    histFilter = f;
    notifyListeners();
  }

  // --- tasks ---
  bool addTask(String title, String project, DateTime d, String? goalId) {
    title = title.trim();
    if (title.isEmpty) return false;
    tasks.add({
      'id': newId(), 'title': title, 'date': iso(d), 'goal': goalId,
      'project': project, 'done': false,
    });
    allDays = false;
    day = d;
    _commit();
    return true;
  }

  void updateTask(String id, {String? title, String? project, DateTime? d, String? goalId, bool clearGoal = false}) {
    final x = findTask(id);
    if (x == null) return;
    if (title != null && title.trim().isNotEmpty) x['title'] = title.trim();
    if (project != null) x['project'] = project;
    if (d != null) x['date'] = iso(d);
    if (clearGoal) x['goal'] = null;
    if (goalId != null) x['goal'] = goalId;
    if (selectedId == id && findTask(id)?['project'] != timerProject) selectedId = null;
    _commit();
  }

  void selectTask(String id) {
    if (locked) {
      toast(t('finish_first'));
      return;
    }
    final x = findTask(id);
    if (x == null) return;
    if (x['done'] == true) {
      toast(t('already_done'));
      return;
    }
    selectedId = id;
    timerProject = x['project'] as String;
    notifyListeners();
  }

  /// Ticks / unticks a task. (A goal is ticked by hand with [toggleGoal]; a task linked to a goal only groups under it.)
  void toggleTaskDone(String id) {
    final x = findTask(id);
    if (x == null) return;
    x['done'] = x['done'] != true;
    _commit();
  }

  void deleteTask(String id) {
    final x = findTask(id);
    if (x == null) return;
    tasks.remove(x);
    if (selectedId == id) selectedId = null;
    _commit();
  }

  void shiftDay(int delta) {
    allDays = false;
    day = day.add(Duration(days: delta));
    notifyListeners();
  }

  void setDay(DateTime d) {
    allDays = false;
    day = dateOnly(d);
    notifyListeners();
  }

  void goToday() {
    allDays = false;
    day = dateOnly(DateTime.now());
    notifyListeners();
  }

  void toggleAllDays() {
    allDays = !allDays;
    notifyListeners();
  }

  List<Map<String, dynamic>> visibleTasks() {
    final l = tasks.where((x) => filter == 'All' || x['project'] == filter).toList();
    if (!allDays) l.removeWhere((x) => x['date'] != iso(day));
    l.sort((a, b) => ((a['done'] == true) ? 1 : 0).compareTo((b['done'] == true) ? 1 : 0));
    return l;
  }

  Map<String, int> spentByTask() {
    final m = <String, int>{};
    for (final s in sessions) {
      final id = s['task_id'];
      if (id != null) m[id as String] = (m[id] ?? 0) + (s['minutes'] as int);
    }
    return m;
  }

  // --- goals ---
  String get monthKey => '${goalMonth.year}-${goalMonth.month.toString().padLeft(2, '0')}';
  void shiftMonth(int delta) {
    goalMonth = DateTime(goalMonth.year, goalMonth.month + delta, 1);
    notifyListeners();
  }

  List<Map<String, dynamic>> goalsOfMonth(String key) => goals.where((g) => g['month'] == key).toList();

  bool addGoal(String title, String targetRaw, String category) {
    title = title.trim();
    if (title.isEmpty) return false;
    final raw = targetRaw.trim().isEmpty ? '1' : targetRaw.trim();
    final n = int.tryParse(raw);
    if (n == null) {
      toast(t('bad_target'));
      return false;
    }
    goals.add({
      'id': newId(), 'month': monthKey, 'title': title, 'category': category,
      'target': n.clamp(1, 999), 'progress': 0,
    });
    _commit();
    return true;
  }

  /// A goal is done or not done: ticking sets its progress to the target, unticking sets it back to 0.
  /// (Old goals that had a number: done = progress reached the target.)
  void toggleGoal(String gid) {
    for (final g in goals) {
      if (g['id'] == gid) {
        final done = (g['progress'] as int) >= (g['target'] as int);
        g['progress'] = done ? 0 : g['target'];
        _commit();
        return;
      }
    }
  }

  void bumpGoal(String gid, int delta) {
    Map<String, dynamic>? g;
    for (final x in goals) {
      if (x['id'] == gid) g = x;
    }
    if (g == null) return;
    g['progress'] = ((g['progress'] as int) + delta).clamp(0, g['target'] as int);
    _commit();
  }

  void deleteGoal(String gid) {
    for (final x in tasks) {
      if (x['goal'] == gid) x['goal'] = null;
    }
    goals.removeWhere((g) => g['id'] == gid);
    _commit();
  }

  // --- timer ---
  void setMinutes(int m) {
    if (locked) return;
    pauseTimer();
    total = m * 60;
    remaining = total;
    notifyListeners();
  }

  void setTimerProject(String p) {
    if (locked) return;
    timerProject = p;
    final x = findTask(selectedId);
    if (x != null && x['project'] != p) selectedId = null;
    notifyListeners();
  }

  void setTimerTask(String? id) {
    if (locked) return;
    selectedId = id;
    notifyListeners();
  }

  void toggleTimer() => running ? pauseTimer() : startTimer();

  void startTimer() {
    if (running) return;
    if (ctx == null) {
      final x = findTask(selectedId);
      ctx = {
        'project': timerProject,
        'task_id': x?['id'],
        'task_title': x?['title'] ?? '',
      };
    }
    running = true;
    _endAt = DateTime.now().add(Duration(seconds: remaining));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    _scheduleTimerAlert();
    notifyListeners();
  }

  /// Phone only: a system notification at the end time, so it rings even when the app is in the background / closed.
  void _scheduleTimerAlert() {
    if (!Notify.supported || _endAt == null) return;
    if (settings['sound'] != true && settings['notify'] != true) {
      Notify.cancel();
      return;
    }
    Notify.schedule(
      _endAt!.add(const Duration(seconds: 2)), // 2s later: if the app is open it rings itself first and cancels this
      t('notif_title', {'m': total ~/ 60}),
      rtl ? 'بُوصَلة' : 'Bosalty',
      // a file from the app's own storage can't be played by the system notification: the chime rings in the background
      tone: timerSoundId == TimerSounds.customId ? TimerSounds.defaultId : timerSoundId,
      sound: settings['sound'] == true,
    );
  }

  void pauseTimer({bool keepAlert = false}) {
    running = false;
    _ticker?.cancel();
    _ticker = null;
    if (!keepAlert) Notify.cancel(); // paused / reset by the user: no notification at the old end time
    notifyListeners();
  }

  void resetTimer({bool keepAlert = false}) {
    pauseTimer(keepAlert: keepAlert);
    ctx = null;
    remaining = total;
    notifyListeners();
  }

  void _tick() {
    if (!running || _endAt == null) return;
    final left = (_endAt!.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    if (left != remaining) {
      remaining = math.max(0, left);
      notifyListeners();
    }
    if (left <= 0) _finish();
  }

  void _finish() {
    running = false;
    _ticker?.cancel();
    final mins = total ~/ 60;
    final c = ctx ?? {'project': timerProject, 'task_id': null, 'task_title': ''};
    final now = DateTime.now();
    final when = '${iso(now)}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    sessions.add({'id': newId(), 'when': when, 'minutes': mins, ...c});
    resetTimer(keepAlert: true); // keep the notification: it is the one that rings on the phone
    if (settings['sound'] == true) {
      _ringInApp();
      HapticFeedback.heavyImpact();
    }
    _commit();
    if (settings['notify'] == true) {
      final pend = pendingTasks;
      final msg = t('notif_title', {'m': mins}) + ' ' +
          (pend.isEmpty
              ? t('notif_all_done')
              : t('notif_pending', {
                  'n': pend.length,
                  'tasks': pend.take(3).map((x) => x['title']).join(rtl ? '، ' : ', ') + (pend.length > 3 ? '...' : ''),
                }));
      toast(msg);
    }
  }

  /// Windows / web, and the phone while the app is open: play the chosen tone here.
  /// Phone in the background: the scheduled notification rings instead.
  Future<void> _ringInApp() async {
    if (Notify.supported) {
      final open = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!open && await Notify.canNotify()) return; // in the background the scheduled notification rings
      if (open) Notify.cancel(); // app is open: ring here once, no second ring from the notification
    }
    await TimerSounds.play(timerSoundId);
  }

  // --- prayer + adhkar reminders (system notifications on Android / iOS) ---
  String _prayerSig = '', _adhkarSig = '';

  /// Keeps the phone's scheduled notifications in step with the settings. Safe to call very often:
  /// it only reschedules when the day, the language, the city or an on/off setting changed.
  void syncPrayerAlerts() {
    if (!Notify.supported) return;
    _syncPrayers();
    _syncAdhkarAlerts();
  }

  void _syncPrayers() {
    final on = settings['prayer_alerts'] == true;
    final today = dateOnly(PrayerConfig.now());
    final sig = on ? '${iso(today)}|$lang|${PrayerConfig.sig}' : 'off';
    if (sig == _prayerSig) return;
    _prayerSig = sig;
    if (!on) {
      Notify.clearPrayers();
      return;
    }
    final items = <PrayerAlert>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      final times = prayerTimes(date);
      for (final k in prayers) {
        items.add(PrayerAlert(PrayerConfig.instant(date, times[k]!), t('pray_title', {'p': t(k)}), t('pray_body')));
      }
    }
    Notify.schedulePrayers(items);
  }

  /// true if the morning / evening adhkar list ('morning' | 'evening') was already finished today.
  bool adhkarDoneToday(String kind) {
    final day = iso(DateTime.now());
    for (final e in WorshipLog.adhkarEntries(this)) {
      if (e['kind'] == kind && '${e['when']}'.startsWith(day)) return true;
    }
    return false;
  }

  /// Morning adhkar: 30 minutes after Fajr. Evening adhkar: 30 minutes after Asr.
  /// (so they follow the season and the city by themselves). Today's one is skipped once you finished that list.
  void _syncAdhkarAlerts() {
    final m = settings['adhkar_morning_alert'] == true;
    final e = settings['adhkar_evening_alert'] == true;
    final today = dateOnly(PrayerConfig.now());
    final dm = (m || e) && adhkarDoneToday('morning');
    final de = (m || e) && adhkarDoneToday('evening');
    final sig = (m || e) ? '${iso(today)}|$lang|${PrayerConfig.sig}|$m$dm|$e$de' : 'off';
    if (sig == _adhkarSig) return;
    _adhkarSig = sig;
    if (!m && !e) {
      Notify.clearAdhkar();
      return;
    }
    final items = <PrayerAlert>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      final times = prayerTimes(date);
      if (m && !(i == 0 && dm)) {
        items.add(PrayerAlert(PrayerConfig.instant(date, times['fajr']! + 0.5),
            rtl ? 'أذكار الصباح' : 'Morning adhkar',
            rtl ? 'خد دقيقتين وابدأ يومك بالأذكار' : 'Take two minutes to start your day with adhkar'));
      }
      if (e && !(i == 0 && de)) {
        items.add(PrayerAlert(PrayerConfig.instant(date, times['asr']! + 0.5),
            rtl ? 'أذكار المساء' : 'Evening adhkar',
            rtl ? 'خد دقيقتين واختم يومك بالأذكار' : 'Take two minutes to end your day with adhkar'));
      }
    }
    Notify.scheduleAdhkar(items);
  }

  // --- report ---
  String monthlyReport() {
    final gm = goalMonth;
    final mName = '${kMonths[lang]![gm.month - 1]} ${gm.year}';
    final mGoals = goalsOfMonth(monthKey);
    final doneGoals = mGoals.where((g) => g['progress'] >= g['target']).length;
    final rate = mGoals.isEmpty ? 0.0 : doneGoals / mGoals.length * 100;
    final mSessions = sessions.where((s) {
      final d = DateTime.tryParse(s['when'] ?? '');
      return d != null && d.year == gm.year && d.month == gm.month;
    }).toList();
    final focus = mSessions.fold<int>(0, (a, s) => a + (s['minutes'] as int));
    final per = <String, int>{};
    for (final s in mSessions) {
      per[s['project']] = (per[s['project']] ?? 0) + (s['minutes'] as int);
    }
    final mTasks = tasks.where((x) {
      final d = DateTime.tryParse(x['date'] ?? '');
      return d != null && d.year == gm.year && d.month == gm.month;
    }).toList();
    final doneTasks = mTasks.where((x) => x['done'] == true).length;
    final lines = <String>[
      '📊 ${t('report_title')} — $mName',
      '=' * 45,
      '🎯 ${t('tab_goals')}: $doneGoals / ${mGoals.length} (${rate.toStringAsFixed(1)}%)',
      '⏱️ ${t('total')}: ${fmtMin(focus)} (${mSessions.length} ${t('tab_focus')})',
      '✅ ${t('tasks')}: $doneTasks / ${mTasks.length}',
      '-' * 45,
      '📁 ${t('work')}:',
    ];
    final order = [...projectKeys, ...per.keys.where((k) => !projectKeys.contains(k))];
    for (final p in order) {
      if ((per[p] ?? 0) > 0) lines.add('  • ${pdisp(p)}: ${fmtMin(per[p]!)}');
    }
    return lines.join('\n');
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pushTimer?.cancel();
    _pullTimer?.cancel();
    _stopRealtime();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
