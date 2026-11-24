import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'notify.dart';
import 'strings.dart';

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
const renames = {'umaime': 'Umami', 'مشروع التخرج': 'Graduation Project', 'Religion': 'Freelance'};
const xpPerLevel = 100;
/// Red used for errors, delete buttons and urgent tasks.
const kUrgent = Color(0xFFE11D48);
const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const badgeKeys = [
  'first_task', 'five_tasks', 'ten_tasks', 'first_pomo', 'ten_pomo',
  'streak_3', 'streak_7', 'first_goal',
];
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
  Pal(this.dark, String accentKey)
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
  Color proj(String p) => projectColors[p]?[dark ? 1 : 0] ?? accent;
  Color tint(String p) => goalTint[p]?[dark ? 1 : 0] ?? card2;
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

DateTime _lastWeekday(int y, int m, int wd /* Mon=0 */) {
  final end = (m < 12 ? DateTime(y, m + 1, 1) : DateTime(y + 1, 1, 1)).subtract(const Duration(days: 1));
  return end.subtract(Duration(days: ((end.weekday - 1) - wd) % 7));
}

/// Prayer times for Cairo in hours (same algorithm as the Python app).
Map<String, double> prayerTimes(DateTime d) {
  const lat = 30.0444, lng = 31.2357;
  final tz = (!d.isBefore(_lastWeekday(d.year, 4, 4)) && !d.isAfter(_lastWeekday(d.year, 10, 3))) ? 3 : 2;
  final epochDays = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch / 86400000.0;
  final dd = epochDays + 2440587.5 + 0.5 - lng / 360 - 2451545.0;
  double rad(double x) => x * math.pi / 180;
  double deg(double x) => x * 180 / math.pi;
  final g = rad((357.529 + 0.98560028 * dd) % 360);
  final q = (280.459 + 0.98564736 * dd) % 360;
  final L = rad((q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) % 360);
  final e = rad(23.439 - 0.00000036 * dd);
  final ra = (deg(math.atan2(math.cos(e) * math.sin(L), math.cos(L))) / 15) % 24;
  final decl = math.asin(math.sin(e) * math.sin(L));
  final eqt = ((q / 15 - ra + 12) % 24) - 12;
  final noon = 12 + tz - lng / 15 - eqt;
  final la = rad(lat);
  double t(double a) {
    final x = (-math.sin(rad(a)) - math.sin(decl) * math.sin(la)) / (math.cos(decl) * math.cos(la));
    return deg(math.acos(x.clamp(-1.0, 1.0))) / 15;
  }

  final asrA = -deg(math.atan(1 / (1 + math.tan((la - decl).abs()))));
  return {
    'fajr': noon - t(19.5), 'dhuhr': noon, 'asr': noon + t(asrA),
    'maghrib': noon + t(0.833), 'isha': noon + t(17.5),
  };
}

// ---------------- settings defaults ----------------
Map<String, dynamic> defaultSettings() => {
      'lang': 'en', 'theme': 'light', 'accent': 'red',
      'font_global': 1.0, 'font_header': 1.0, 'font_tasks': 1.0,
      'font_timer': 1.0, 'font_history': 1.0, 'font_goals': 1.0,
      'compact_tasks': false, 'show_tiles': true, 'default_all_days': false,
      'presets': [15, 25, 45, 60],
      'xp_easy': 10, 'xp_medium': 20, 'xp_hard': 30, 'goal_xp': 50,
      'show_badges': true, 'show_prayers': true, 'sound': true, 'notify': true,
      'prayer_alerts': true,
      'mushaf_font': 28.0,
    };

Map<String, dynamic> defaultData() => {
      'tasks': [], 'xp': 0, 'done_count': 0, 'pomodoros': 0, 'days': [],
      'badges': [], 'sessions': [], 'goals': [], 'goals_done': 0,
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
    final base = defaultData();
    try {
      final raw = _prefs!.getString('bosalty_data');
      if (raw != null) base.addAll(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
    _normalize(base);
    data = base;
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
  /// Everything in the app (tasks, goals, sessions, XP, badges, settings, profile) as one JSON text.
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
      for (final k in ['tasks', 'goals', 'sessions', 'days', 'badges']) {
        if (base[k] is! List) base[k] = [];
      }
      _normalize(base);

      if (keepSafety) _prefs?.setString(_safetyKey, jsonEncode(data));
      data = base;
      selectedId = null;
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
    data['_updated'] = _nowStamp();
    _prefs?.setString('bosalty_data', jsonEncode(data));
    _schedulePush();
  }

  // ---------------- cloud sync (Supabase table app_data: user_id, data, updated_at) ----------------
  Timer? _pushTimer, _pullTimer;
  bool _pushPending = false;
  String _lastSyncErr = '';
  bool _syncOkShown = false;

  void _syncFail(Object e) {
    final m = '$e'.replaceAll('\n', ' ');
    final msg = 'Sync error: ${m.length > 150 ? m.substring(0, 150) : m}';
    if (msg != _lastSyncErr) {
      _lastSyncErr = msg;
      toast(msg);
    }
  }

  void _syncOk() {
    if (_lastSyncErr.isNotEmpty || !_syncOkShown) {
      _lastSyncErr = '';
      _syncOkShown = true;
      toast('Cloud sync is working');
    }
  }

  // same format the desktop app writes: 2026-11-23T11:30:00.123456+00:00
  String _nowStamp() {
    var s = DateTime.now().toUtc().toIso8601String().replaceFirst('Z', '');
    final dot = s.indexOf('.');
    s = dot == -1 ? '$s.000000' : s.padRight(dot + 7, '0');
    return '$s+00:00';
  }

  DateTime _stampOf(Map m) =>
      DateTime.tryParse('${m['_updated'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

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
      await c.from('app_data').upsert({
        'user_id': uid,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
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
      await pushNow(); // an earlier upload failed: retry it first
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
        toast('Cloud was empty: uploaded ${tasks.length} tasks');
        return;
      }
      final r = DateTime.tryParse('${head.first['stamp'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final l = _stampOf(data);
      if (r.isAfter(l)) {
        // 2) the cloud copy is newer: download it
        final rows = await c.from('app_data').select('data').eq('user_id', uid).limit(1);
        if (rows.isEmpty) return;
        final remote = Map<String, dynamic>.from(rows.first['data'] as Map);
        final base = defaultData();
        base.addAll(remote);
        base['settings'] = settings; // theme / language / layout stay per device
        _normalize(base);
        data = base;
        _prefs?.setString('bosalty_data', jsonEncode(data));
        if (selectedId != null && findTask(selectedId!) == null) selectedId = null;
        notifyListeners();
        toast('Loaded ${tasks.length} tasks from the cloud');
      } else if (l.isAfter(r)) {
        _pushPending = true;
        await pushNow();
        toast('Phone data is newer: uploaded ${tasks.length} tasks');
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
  Pal get pal => Pal(dark, settings['accent'] as String);
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

  String pdisp(String k) {
    if (k == 'All') return t('all');
    return lang == 'ar' ? (projectAr[k] ?? k) : (projectEn[k] ?? k);
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

  String streakText(int n) {
    if (rtl) {
      final w = n == 1 ? 'يوم' : n == 2 ? 'يومان' : n <= 10 ? 'أيام' : 'يومًا';
      return t('streak', {'n': n == 2 ? '' : n, 'd': w}).replaceAll('  ', ' ');
    }
    return t('streak', {'n': n, 'd': n == 1 ? 'day' : 'days'});
  }

  List<MapEntry<String, int>> get diffs => [
        MapEntry('easy', (settings['xp_easy'] as num).toInt()),
        MapEntry('medium', (settings['xp_medium'] as num).toInt()),
        MapEntry('hard', (settings['xp_hard'] as num).toInt()),
      ];

  int get level => (data['xp'] as int) ~/ xpPerLevel + 1;
  String get levelTitle => t('lv${math.min(level - 1, 4)}');

  int get streakCount {
    final days = (data['days'] as List).cast<String>().toSet();
    var d = dateOnly(DateTime.now());
    if (!days.contains(iso(d))) d = d.subtract(const Duration(days: 1));
    var c = 0;
    while (days.contains(iso(d))) {
      c++;
      d = d.subtract(const Duration(days: 1));
    }
    return c;
  }

  bool _badge(String k) {
    final d = data;
    switch (k) {
      case 'first_task': return d['done_count'] >= 1;
      case 'five_tasks': return d['done_count'] >= 5;
      case 'ten_tasks': return d['done_count'] >= 10;
      case 'first_pomo': return d['pomodoros'] >= 1;
      case 'ten_pomo': return d['pomodoros'] >= 10;
      case 'streak_3': return streakCount >= 3;
      case 'streak_7': return streakCount >= 7;
      case 'first_goal': return d['goals_done'] >= 1;
    }
    return false;
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
    _commitLocal();
    return true;
  }

  void toggleTheme() => setSetting('theme', dark ? 'light' : 'dark');
  void toggleLang() => setSetting('lang', rtl ? 'en' : 'ar', needsUnlocked: true);

  void resetSettings() {
    if (locked) {
      toast(t('finish_first'));
      return;
    }
    data['settings'] = defaultSettings();
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

  // --- XP ---
  void award(int xp, String why) {
    final oldLevel = level;
    data['xp'] = (data['xp'] as int) + xp;
    final today = iso(DateTime.now());
    final days = data['days'] as List;
    if (!days.contains(today)) days.add(today);
    final notes = <String>[t('toast', {'n': xp, 'why': why})];
    if (level > oldLevel) notes.add(t('levelup', {'n': level}));
    for (final k in badgeKeys) {
      final badges = data['badges'] as List;
      if (!badges.contains(k) && _badge(k)) {
        badges.add(k);
        notes.add(t('newbadge', {'name': t('b_$k')}));
      }
    }
    save();
    toast(notes.join('   •   '));
  }

  // --- tasks ---
  bool addTask(String title, String project, int xp, DateTime d, String? goalId) {
    title = title.trim();
    if (title.isEmpty) return false;
    tasks.add({
      'id': newId(), 'title': title, 'date': iso(d), 'goal': goalId,
      'project': project, 'xp': xp, 'done': false,
    });
    allDays = false;
    day = d;
    _commit();
    return true;
  }

  void updateTask(String id, {String? title, String? project, int? xp, DateTime? d, String? goalId, bool clearGoal = false}) {
    final x = findTask(id);
    if (x == null) return;
    if (title != null && title.trim().isNotEmpty) x['title'] = title.trim();
    if (project != null) x['project'] = project;
    if (xp != null) x['xp'] = xp;
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

  void toggleTaskDone(String id) {
    final x = findTask(id);
    if (x == null) return;
    if (x['done'] == true) {
      x['done'] = false;
      if ((data['done_count'] as int) > 0) data['done_count'] = (data['done_count'] as int) - 1;
      if (x['goal'] != null) {
        bumpGoal(x['goal'] as String, -1);
      } else {
        _commit();
      }
    } else {
      x['done'] = true;
      data['done_count'] = (data['done_count'] as int) + 1;
      award(x['xp'] as int, t('why_task', {'t': x['title']}));
      if (x['goal'] != null) bumpGoal(x['goal'] as String, 1);
    }
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
      'target': n.clamp(1, 999), 'progress': 0, 'rewarded': false,
    });
    _commit();
    return true;
  }

  void bumpGoal(String gid, int delta) {
    Map<String, dynamic>? g;
    for (final x in goals) {
      if (x['id'] == gid) g = x;
    }
    if (g == null) return;
    g['progress'] = ((g['progress'] as int) + delta).clamp(0, g['target'] as int);
    if ((g['progress'] as int) >= (g['target'] as int) && g['rewarded'] != true) {
      g['rewarded'] = true;
      data['goals_done'] = (data['goals_done'] as int) + 1;
      award((settings['goal_xp'] as num).toInt(), t('why_goal', {'t': g['title']}));
    } else {
      if ((g['progress'] as int) < (g['target'] as int) && g['rewarded'] == true) {
        g['rewarded'] = false;
        if ((data['goals_done'] as int) > 0) data['goals_done'] = (data['goals_done'] as int) - 1;
      }
      _commit();
    }
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
    notifyListeners();
  }

  void pauseTimer() {
    running = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void resetTimer() {
    pauseTimer();
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
    data['pomodoros'] = (data['pomodoros'] as int) + 1;
    resetTimer();
    if (settings['sound'] == true) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    award(mins, t('why_session', {'m': mins, 'p': pdisp(c['project'] as String)}));
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

  // --- prayer reminders (system notifications on Android / iOS) ---
  String _prayerSig = '';

  /// Keeps the phone's scheduled prayer notifications in step with the settings.
  /// Safe to call very often: it only reschedules when the day, the language
  /// or the on/off setting changed.
  void syncPrayerAlerts() {
    if (!Notify.supported) return;
    final on = settings['prayer_alerts'] == true;
    final today = dateOnly(DateTime.now());
    final sig = on ? '${iso(today)}|$lang' : 'off';
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
        final mins = (times[k]! * 60).round();
        final at = DateTime(date.year, date.month, date.day, mins ~/ 60, mins % 60);
        items.add(PrayerAlert(at, t('pray_title', {'p': t(k)}), t('pray_body')));
      }
    }
    Notify.schedulePrayers(items);
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
    for (final p in projects) {
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
