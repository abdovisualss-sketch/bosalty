import 'package:flutter/material.dart';

import 'state.dart';

/// What the app remembers about worship, so the History tab and the Quran reader can show it.
///
///   data['adhkar_log'] = [ {id, kind: morning|evening|fav, when: 'YYYY-MM-DDTHH:MM:SS', n: how many adhkar} ]
///   data['quran_log']  = { 'YYYY-MM-DD': [ [page, minuteOfDay], ... ] }   (pages in the order they were read)
///
/// Both live inside the normal app data, so they are saved, backed up and synced like everything else.
/// These functions only change the data: the caller calls AppState.save().
class WorshipLog {
  WorshipLog._();

  // ---------------------------------------------------------------- adhkar

  /// The three lists of the Adhkar tab, in the same order as its buttons.
  static const adhkarKinds = ['morning', 'evening', 'fav'];

  static String adhkarTitle(AppState s, String kind) {
    switch (kind) {
      case 'morning':
        return s.rtl ? 'أذكار الصباح' : 'Morning adhkar';
      case 'evening':
        return s.rtl ? 'أذكار المساء' : 'Evening adhkar';
      default:
        return s.rtl ? 'أذكاري المفضلة' : 'My favorites';
    }
  }

  static IconData adhkarIcon(String kind) {
    switch (kind) {
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'evening':
        return Icons.nightlight_round;
      default:
        return Icons.favorite_rounded;
    }
  }

  static Color adhkarColor(String kind) {
    switch (kind) {
      case 'morning':
        return const Color(0xFFD97706);
      case 'evening':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFFF43F5E);
    }
  }

  static List<Map<String, dynamic>> adhkarEntries(AppState s) {
    final raw = s.data['adhkar_log'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  /// Writes "finished this list today". Once per list per day.
  /// Returns true if it was added now, false if today's entry was already there.
  static bool logAdhkar(AppState s, String kind, int count, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final day = iso(t);
    final raw = s.data['adhkar_log'];
    final list = raw is List ? raw.toList() : <dynamic>[];
    for (final e in list) {
      if (e is Map && e['kind'] == kind && '${e['when']}'.startsWith(day)) return false;
    }
    list.add({
      'id': newId(),
      'kind': kind,
      'when': t.toIso8601String().substring(0, 19),
      'n': count,
    });
    s.data['adhkar_log'] = list;
    return true;
  }

  // ---------------------------------------------------------------- Quran reading

  static Map<String, dynamic> _quranMap(AppState s) {
    final cur = s.data['quran_log'];
    if (cur is Map<String, dynamic>) return cur;
    final m = cur is Map ? Map<String, dynamic>.from(cur) : <String, dynamic>{};
    s.data['quran_log'] = m;
    return m;
  }

  /// Marks [page] as read today. A page counts once a day.
  /// Returns true if it was new today.
  static bool addQuranPage(AppState s, int page, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final m = _quranMap(s);
    final key = iso(t);
    final cur = m[key];
    final list = cur is List ? cur.toList() : <dynamic>[];
    for (final e in list) {
      if (e is List && e.isNotEmpty && e[0] == page) return false;
    }
    list.add([page, t.hour * 60 + t.minute]);
    m[key] = list;
    return true;
  }

  /// The pages read on [day], in the order they were read.
  static List<QuranRead> quranOn(AppState s, DateTime day) {
    final raw = s.data['quran_log'];
    if (raw is! Map) return const [];
    final list = raw[iso(day)];
    if (list is! List) return const [];
    final out = <QuranRead>[];
    for (final e in list) {
      if (e is List && e.length >= 2 && e[0] is num && e[1] is num) {
        out.add(QuranRead((e[0] as num).toInt(), (e[1] as num).toInt()));
      }
    }
    return out;
  }

  /// Every day ('YYYY-MM-DD') that has reading in it.
  static List<String> quranDays(AppState s) {
    final raw = s.data['quran_log'];
    if (raw is! Map) return const [];
    return [for (final k in raw.keys) '$k'];
  }

  /// Pages that were read one after the other, close in time, form one "reading".
  static List<QuranRun> runsOf(List<QuranRead> reads, {int gapMinutes = 30}) {
    final runs = <QuranRun>[];
    for (final r in reads) {
      if (runs.isNotEmpty) {
        final l = runs.last;
        if (r.page == l.last + 1 && r.minute >= l.endMin && r.minute - l.endMin <= gapMinutes) {
          runs[runs.length - 1] = QuranRun(l.first, r.page, l.startMin, r.minute);
          continue;
        }
      }
      runs.add(QuranRun(r.page, r.page, r.minute, r.minute));
    }
    return runs;
  }
}

/// One page that counted as read, and the minute of the day it was counted.
class QuranRead {
  const QuranRead(this.page, this.minute);
  final int page, minute;
}

/// One sitting of reading: pages [first]..[last] (in a row), from [startMin] to [endMin] (minutes of the day).
class QuranRun {
  const QuranRun(this.first, this.last, this.startMin, this.endMin);
  final int first, last, startMin, endMin;
  int get pages => last - first + 1;
}
