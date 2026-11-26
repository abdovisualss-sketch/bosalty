import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';
import 'ui.dart';
import 'worship_log.dart';

/// المصحف الشريف: Quran text (Hafs, Madani 604 pages) with an index of
/// surahs / juz / hizb / pages, bookmarks, search and a page-by-page reader.
///
/// Text: Uthmani script from The Noble Qur'an Encyclopedia (quran-json, CC-BY-4.0).
/// Page / juz / hizb boundaries: quran-meta (MIT). Font: Amiri Quran (SIL OFL).

// ---------------------------------------------------------------- helpers
const _arDigits = '٠١٢٣٤٥٦٧٨٩';

String arNum(int n) => n.toString().split('').map((c) => _arDigits[int.parse(c)]).join();

/// "٢٥٥" -> "255"
String latinDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final i = _arDigits.runes.toList().indexOf(r);
    b.write(i >= 0 ? '$i' : String.fromCharCode(r));
  }
  return b.toString();
}

/// Removes tashkeel / Quranic marks and unifies letter shapes, so a search typed with
/// the normal spelling matches the Uthmani text.
String normalizeAr(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x0610 && r <= 0x061A) ||
        (r >= 0x064B && r <= 0x065F) ||
        r == 0x0670 ||
        (r >= 0x06D6 && r <= 0x06ED) ||
        r == 0x0640) {
      continue;
    }
    if (r == 0x0671 || r == 0x0623 || r == 0x0625 || r == 0x0622) {
      b.writeCharCode(0x0627); // all alef shapes -> ا
    } else if (r == 0x0649) {
      b.writeCharCode(0x064A); // ى -> ي
    } else if (r == 0x0629) {
      b.writeCharCode(0x0647); // ة -> ه
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// number of items in a[0..n) that are <= v (a is sorted)
int _countLe(List<int> a, int v, int n) {
  var lo = 0, hi = n;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (a[mid] <= v) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

// ---------------------------------------------------------------- data
class QuranData {
  QuranData._(this.names, this.translit, this.meccan, this.ayat, this.juz, this.hizbq, this.page,
      this.sajda) {
    starts = List<int>.filled(115, 0);
    var id = 1;
    for (var i = 0; i < 114; i++) {
      starts[i] = id;
      id += ayat[i].length;
    }
    starts[114] = id; // 6237
  }

  final List<String> names, translit;
  final List<bool> meccan;
  final List<List<String>> ayat;
  final List<int> juz, hizbq, page, sajda; // absolute ayah ids (1..6236)
  late final List<int> starts;

  static QuranData? _cache;

  /// The loaded text, or null while it is still loading (the Mushaf screen loads it at start-up).
  static QuranData? get cached => _cache;

  static Future<QuranData> load() async {
    if (_cache != null) return _cache!;
    final q = jsonDecode(await rootBundle.loadString('assets/quran/quran.json')) as Map;
    final m = jsonDecode(await rootBundle.loadString('assets/quran/meta.json')) as Map;
    final surahs = (q['s'] as List).cast<Map>();
    List<int> ints(String k) => (m[k] as List).map((e) => e as int).toList();
    return _cache = QuranData._(
      [for (final s in surahs) s['n'] as String],
      [for (final s in surahs) s['t'] as String],
      [for (final s in surahs) s['m'] == 1],
      [
        for (final s in surahs) [for (final a in (s['a'] as List)) a as String]
      ],
      ints('juz'),
      ints('hizbq'),
      ints('page'),
      ints('sajda'),
    );
  }

  int idOf(int surah, int ayah) => starts[surah - 1] + ayah - 1;
  int surahOf(int id) => _countLe(starts, id, 114);
  int ayahOf(int id) => id - starts[surahOf(id) - 1] + 1;
  String text(int id) => ayat[surahOf(id) - 1][ayahOf(id) - 1];
  int pageOf(int id) => _countLe(page, id, 604);
  int juzOf(int id) => _countLe(juz, id, 30);
  int hizbQuarterOf(int id) => _countLe(hizbq, id, 240);
  int pageEnd(int pg) => pg >= 604 ? 6236 : page[pg] - 1;
  int ayatOnPage(int pg) => pageEnd(pg) - page[pg - 1] + 1;

  /// first / last ayah id of juz j (1..30) and of hizb h (1..60 = 4 hizb-quarters each)
  int juzStart(int j) => juz[j - 1];
  int juzEnd(int j) => j >= 30 ? 6236 : juz[j] - 1;
  int hizbStart(int h) => hizbq[(h - 1) * 4];
  int hizbEnd(int h) => h >= 60 ? 6236 : hizbq[h * 4] - 1;
}

// ---------------------------------------------------------------- today's reading log
/// A page counts as "read" only after it has stayed on screen this long (so flipping through pages doesn't count).
const _readDwell = Duration(seconds: 15);

/// "٨ صفحات" / "8 pages"
String pagesText(AppState s, int c) {
  if (!s.rtl) return c == 1 ? '1 page' : '$c pages';
  if (c == 1) return 'صفحة واحدة';
  if (c == 2) return 'صفحتان';
  return c <= 10 ? '${arNum(c)} صفحات' : '${arNum(c)} صفحة';
}

/// First – last surah of a reading, e.g. "النساء – المائدة" (one name if it stays inside one surah).
String runSurahs(QuranData q, QuranRun r, bool rtl, {bool full = false}) {
  String nm(int su) => rtl ? (full ? 'سورة ${q.names[su - 1]}' : q.names[su - 1]) : q.translit[su - 1];
  final a = q.surahOf(q.page[r.first - 1]), b = q.surahOf(q.pageEnd(r.last));
  return a == b ? nm(a) : '${nm(a)} – ${nm(b)}';
}

/// "ص ٩٧–١٠٦" / "p. 97–106"
String runPages(QuranRun r, bool rtl) {
  String v(int x) => rtl ? arNum(x) : '$x';
  final span = r.first == r.last ? v(r.first) : '${v(r.first)}–${v(r.last)}';
  return rtl ? 'ص $span' : 'p. $span';
}

/// Everything read on one day, worked out from the list of pages: totals, the readings, the surahs, the juz.
class QuranDay {
  QuranDay._(this.runs, this.pages, this.ayat, this.surahAyat, this.juz);
  final List<QuranRun> runs; // in the order they happened
  final int pages, ayat;
  final Map<int, int> surahAyat; // surah no. -> verses on the pages read (in order of first appearance)
  final List<int> juz; // juz numbers touched, sorted

  static QuranDay of(QuranData q, List<QuranRead> reads) {
    final ok = [
      for (final r in reads)
        if (r.page >= 1 && r.page <= 604) r,
    ];
    var ayat = 0;
    final su = <int, int>{};
    final jz = <int>{};
    for (final r in ok) {
      final from = q.page[r.page - 1], to = q.pageEnd(r.page);
      ayat += to - from + 1;
      jz.add(q.juzOf(from));
      for (var id = from; id <= to; id++) {
        final k = q.surahOf(id);
        su[k] = (su[k] ?? 0) + 1;
      }
    }
    return QuranDay._(WorshipLog.runsOf(ok), ok.length, ayat, su, jz.toList()..sort());
  }
}

// ---------------------------------------------------------------- screen
class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});
  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  QuranData? _q;
  SharedPreferences? _prefs;
  String? _error;

  bool _reading = false;
  bool _active = true; // false while another tab is on screen (Mushaf kept alive underneath)
  bool _wasActive = true;
  Timer? _dwell; // counts the page as read once it has stayed on screen long enough
  int _page = 1;
  int? _focus; // ayah id to highlight
  /// Reading text size: comes from Settings (so it can be changed there too).
  double get _font => ((AppScope.of(context).settings['mushaf_font'] as num?)?.toDouble() ?? 28.0)
      .clamp(18.0, 48.0)
      .toDouble();
  List<int> _marks = [];
  PageController? _pc;

  final Map<int, TapGestureRecognizer> _rec = {};
  final TextEditingController _surahSearch = TextEditingController();
  final TextEditingController _textSearch = TextEditingController();
  String _surahQ = '';
  List<String>? _norm;
  List<int> _hits = [];
  String _hitQ = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _q = await QuranData.load();
      _page = (_prefs!.getInt('mushaf_page') ?? 1).clamp(1, 604).toInt();
      // one-time move of the old per-screen size into the app settings
      final oldFont = _prefs!.getDouble('mushaf_font');
      if (oldFont != null && mounted) {
        AppScope.of(context).setSetting('mushaf_font', oldFont);
        await _prefs!.remove('mushaf_font');
      }
      _marks = [
        for (final m in (_prefs!.getStringList('mushaf_marks') ?? const <String>[]))
          if (int.tryParse(m) != null) int.parse(m)
      ];
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  /// Hides the app header (logo / tasks chip / tour / settings) while reading.
  void _syncHeader() {
    final hide = _reading && _active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && mushafReading.value != hide) mushafReading.value = hide;
    });
  }

  /// The page on screen counts as "read" (and goes to today's log / History) after [_readDwell].
  void _startDwell() {
    _dwell?.cancel();
    if (!_reading || !_active || _q == null) return;
    final pg = _page;
    _dwell = Timer(_readDwell, () {
      if (!mounted || !_reading || !_active || _page != pg) return;
      final s = AppScope.of(context);
      if (WorshipLog.addQuranPage(s, pg)) {
        s.save();
        setState(() {}); // refresh the bar under the page
      }
    });
  }

  /// Stops counting while another tab is on screen, starts again when the Mushaf comes back.
  void _syncDwell() {
    if (_active == _wasActive) return;
    _wasActive = _active;
    if (_active) {
      _startDwell();
    } else {
      _dwell?.cancel();
    }
  }

  @override
  void dispose() {
    // not while the tree is locked: do it right after this frame
    WidgetsBinding.instance.addPostFrameCallback((_) => mushafReading.value = false);
    _dwell?.cancel();
    for (final r in _rec.values) {
      r.dispose();
    }
    _pc?.dispose();
    _surahSearch.dispose();
    _textSearch.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- actions
  void _open(int page, {int? ayah}) {
    final pg = page.clamp(1, 604).toInt();
    _pc?.dispose();
    _pc = PageController(initialPage: pg - 1);
    setState(() {
      _page = pg;
      _focus = ayah;
      _reading = true;
    });
    _prefs?.setInt('mushaf_page', pg);
    _startDwell();
  }

  void _saveMarks() =>
      _prefs?.setStringList('mushaf_marks', [for (final m in _marks) '$m']);

  void _toggleMark(int id) {
    final s = AppScope.of(context);
    setState(() {
      if (_marks.contains(id)) {
        _marks.remove(id);
        s.toast(s.rtl ? 'تمت إزالة العلامة' : 'Bookmark removed');
      } else {
        _marks.add(id);
        s.toast(s.rtl ? 'تمت إضافة العلامة' : 'Bookmark added');
      }
    });
    _saveMarks();
  }

  TapGestureRecognizer _recFor(int id) =>
      _rec.putIfAbsent(id, () => TapGestureRecognizer()..onTap = () => _ayahSheet(id));

  void _ayahSheet(int id) {
    final q = _q!;
    final s = AppScope.of(context);
    final p = s.pal;
    final su = q.surahOf(id), ay = q.ayahOf(id);
    final marked = _marks.contains(id);
    setState(() => _focus = id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Txt(
              s.rtl
                  ? 'سورة ${q.names[su - 1]} · آية ${arNum(ay)}'
                  : 'Surah ${q.translit[su - 1]} · verse $ay',
              size: 16,
              bold: true,
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(marked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                  color: p.accent),
              title: Txt(marked
                  ? (s.rtl ? 'إزالة العلامة' : 'Remove bookmark')
                  : (s.rtl ? 'إضافة علامة' : 'Add bookmark'), size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _toggleMark(id);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.copy_rounded, color: p.accent),
              title: Txt(s.rtl ? 'نسخ الآية' : 'Copy verse', size: 14),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(
                    text: '${q.text(id)} ﴿${arNum(ay)}﴾ [${q.names[su - 1]}]'));
                s.toast(s.rtl ? 'تم نسخ الآية' : 'Verse copied');
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _fontSheet() {
    final p = AppScope.of(context).pal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) {
        final s = AppScope.of(ctx);
        final cur = ((s.settings['mushaf_font'] as num?)?.toDouble() ?? 28.0).clamp(18.0, 48.0).toDouble();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Txt(s.rtl ? 'حجم الخط' : 'Font size', size: 15, bold: true),
              Slider(
                value: cur,
                min: 18,
                max: 48,
                divisions: 15,
                label: cur.round().toString(),
                activeColor: s.pal.accent,
                onChanged: (v) => s.setSetting('mushaf_font', v),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _goDialog() {
    final q = _q!;
    final s = AppScope.of(context);
    final p = s.pal;
    final pageC = TextEditingController();
    final surahC = TextEditingController();
    final ayahC = TextEditingController();
    String L(String ar, String en) => s.rtl ? ar : en;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Txt(L('اذهب إلى', 'Go to'), size: 17, bold: true),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: pageC,
            keyboardType: TextInputType.number,
            style: TextStyle(color: p.text),
            decoration: fieldDeco(p, L('رقم الصفحة (١ - ٦٠٤)', 'Page number (1 - 604)')),
          ),
          const SizedBox(height: 10),
          Txt(L('أو', 'or'), size: 12, color: p.muted),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: surahC,
                keyboardType: TextInputType.number,
                style: TextStyle(color: p.text),
                decoration: fieldDeco(p, L('رقم السورة', 'Surah no.')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: ayahC,
                keyboardType: TextInputType.number,
                style: TextStyle(color: p.text),
                decoration: fieldDeco(p, L('رقم الآية', 'Verse no.')),
              ),
            ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Txt(L('إلغاء', 'Cancel'), color: p.muted)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: () {
              final pg = int.tryParse(latinDigits(pageC.text.trim()));
              final su = int.tryParse(latinDigits(surahC.text.trim()));
              final ay = int.tryParse(latinDigits(ayahC.text.trim())) ?? 1;
              if (pg != null && pg >= 1 && pg <= 604) {
                Navigator.pop(ctx);
                _jump(pg);
              } else if (su != null && su >= 1 && su <= 114) {
                Navigator.pop(ctx);
                final id = q.idOf(su, ay.clamp(1, q.ayat[su - 1].length).toInt());
                _jump(q.pageOf(id), ayah: id);
              } else {
                s.toast(L('اكتب رقم صفحة أو سورة صحيحًا', 'Enter a valid page or surah number'));
              }
            },
            child: Txt(L('اذهب', 'Go'), bold: true, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// jump inside the reader
  void _jump(int pg, {int? ayah}) {
    setState(() {
      _page = pg;
      _focus = ayah;
    });
    _prefs?.setInt('mushaf_page', pg);
    _pc?.jumpToPage(pg - 1);
    _startDwell();
  }

  void _search(String raw) {
    final q = _q!;
    final out = <int>[];
    final m = RegExp(r'^(\d{1,3})\s*[:/]\s*(\d{1,3})$').firstMatch(latinDigits(raw.trim()));
    if (m != null) {
      final su = int.parse(m.group(1)!), ay = int.parse(m.group(2)!);
      if (su >= 1 && su <= 114 && ay >= 1 && ay <= q.ayat[su - 1].length) out.add(q.idOf(su, ay));
    } else {
      final n = normalizeAr(raw.trim());
      if (n.length >= 2) {
        _norm ??= [for (var i = 1; i <= 6236; i++) normalizeAr(q.text(i))];
        for (var i = 0; i < _norm!.length && out.length < 100; i++) {
          if (_norm![i].contains(n)) out.add(i + 1);
        }
      }
    }
    setState(() {
      _hits = out;
      _hitQ = raw.trim();
    });
  }

  // ---------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    _active = TickerMode.of(context);
    _syncHeader();
    _syncDwell();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Txt(
            s.rtl
                ? 'تعذّر تحميل المصحف. تأكد من إضافة مجلد assets/quran/ في pubspec.yaml.\n$_error'
                : 'Could not load the Quran. Make sure assets/quran/ is listed in pubspec.yaml.\n$_error',
            size: 13,
            align: TextAlign.center,
            color: p.muted,
          ),
        ),
      );
    }
    final q = _q;
    if (q == null) return Center(child: CircularProgressIndicator(color: p.accent));
    return _reading ? _reader(s, p, q) : _index(s, p, q);
  }

  // ---------------------------------------------------------- index
  Widget _row(Pal p,
      {required String lead,
      required String title,
      String? sub,
      String? trail,
      Widget? action,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Box(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
              child: Txt(lead, size: 13, bold: true, color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Txt(title, size: 15, bold: true, maxLines: 1),
                if (sub != null) Txt(sub, size: 11, color: p.muted, maxLines: 2),
              ]),
            ),
            if (trail != null) Txt(trail, size: 12, color: p.muted),
            if (action != null) action,
          ]),
        ),
      ),
    );
  }

  String _snippet(String t, [int words = 6]) {
    final w = t.split(' ');
    return w.length <= words ? t : '${w.take(words).join(' ')} …';
  }

  Widget _index(AppState s, Pal p, QuranData q) {
    String L(String ar, String en) => s.rtl ? ar : en;
    String n(int v) => s.rtl ? arNum(v) : '$v';
    final lastSurah = q.surahOf(q.page[_page - 1]);

    return DefaultTabController(
      length: 6,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _open(_page, ayah: _focus),
            child: Box(
              color: p.sel,
              child: Row(children: [
                Icon(Icons.menu_book_rounded, color: p.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(L('متابعة القراءة', 'Continue reading'), size: 12, color: p.muted),
                    Txt(
                      L('سورة ${q.names[lastSurah - 1]} · صفحة ${arNum(_page)}',
                          'Surah ${q.translit[lastSurah - 1]} · page $_page'),
                      size: 15,
                      bold: true,
                    ),
                  ]),
                ),
                Icon(s.rtl ? Icons.chevron_left : Icons.chevron_right, color: p.accent),
              ]),
            ),
          ),
        ),
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: p.accent,
          unselectedLabelColor: p.muted,
          indicatorColor: p.accent,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: L('السور', 'Surahs')),
            Tab(text: L('الأجزاء', 'Juz')),
            Tab(text: L('الأحزاب', 'Hizb')),
            Tab(text: L('الصفحات', 'Pages')),
            Tab(text: L('العلامات', 'Bookmarks')),
            Tab(text: L('بحث', 'Search')),
          ],
        ),
        Expanded(
          child: TabBarView(children: [
            _surahsTab(s, p, q, L, n),
            _juzTab(s, p, q, L, n),
            _hizbTab(s, p, q, L, n),
            _pagesTab(s, p, q, n),
            _marksTab(s, p, q, L, n),
            _searchTab(s, p, q, L, n),
          ]),
        ),
      ]),
    );
  }

  Widget _surahsTab(AppState s, Pal p, QuranData q, String Function(String, String) L,
      String Function(int) n) {
    final raw = latinDigits(_surahQ.trim());
    final qn = normalizeAr(raw).toLowerCase();
    final list = <int>[];
    for (var i = 1; i <= 114; i++) {
      if (qn.isEmpty ||
          '$i' == raw ||
          normalizeAr(q.names[i - 1]).contains(qn) ||
          q.translit[i - 1].toLowerCase().contains(qn)) {
        list.add(i);
      }
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: TextField(
          controller: _surahSearch,
          style: TextStyle(color: p.text),
          decoration: fieldDeco(p, L('ابحث عن سورة بالاسم أو الرقم', 'Find a surah by name or number')),
          onChanged: (v) => setState(() => _surahQ = v),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: list.length + 1,
          itemBuilder: (c, k) {
            if (k == list.length) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Txt(
                  L('النص: موسوعة القرآن الكريم (CC-BY-4.0) · حدود الصفحات: quran-meta · الخط: Amiri Quran',
                      "Text: The Noble Qur'an Encyclopedia (CC-BY-4.0) · pages: quran-meta · font: Amiri Quran"),
                  size: 10,
                  color: p.muted,
                  align: TextAlign.center,
                ),
              );
            }
            final i = list[k];
            final start = q.starts[i - 1];
            final pg = q.pageOf(start);
            final cnt = q.ayat[i - 1].length;
            return _row(
              p,
              lead: n(i),
              title: L('سورة ${q.names[i - 1]}', q.translit[i - 1]),
              sub: L('${q.meccan[i - 1] ? 'مكية' : 'مدنية'} · ${arNum(cnt)} آية',
                  '${q.meccan[i - 1] ? 'Meccan' : 'Medinan'} · $cnt verses'),
              trail: L('ص ${arNum(pg)}', 'p. $pg'),
              onTap: () => _open(pg),
            );
          },
        ),
      ),
    ]);
  }

  Widget _juzTab(AppState s, Pal p, QuranData q, String Function(String, String) L,
      String Function(int) n) {
    final rows = <Widget>[];
    for (var j = 1; j <= 30; j++) {
      final id = q.juz[j - 1];
      final su = q.surahOf(id);
      rows.add(_row(
        p,
        lead: n(j),
        title: L('الجزء ${arNum(j)}', 'Juz $j'),
        sub: L('${q.names[su - 1]} · آية ${arNum(q.ayahOf(id))}',
            '${q.translit[su - 1]} · verse ${q.ayahOf(id)}'),
        trail: L('ص ${arNum(q.pageOf(id))}', 'p. ${q.pageOf(id)}'),
        onTap: () => _open(q.pageOf(id)),
      ));
    }
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Txt(L('سجدات التلاوة', 'Prostration verses'), size: 14, bold: true, color: p.accent),
    ));
    for (var k = 0; k < q.sajda.length; k++) {
      final id = q.sajda[k];
      final su = q.surahOf(id);
      rows.add(_row(
        p,
        lead: n(k + 1),
        title: L('سورة ${q.names[su - 1]}', q.translit[su - 1]),
        sub: L('آية ${arNum(q.ayahOf(id))}', 'verse ${q.ayahOf(id)}'),
        trail: L('ص ${arNum(q.pageOf(id))}', 'p. ${q.pageOf(id)}'),
        onTap: () => _open(q.pageOf(id), ayah: id),
      ));
    }
    return ListView(padding: const EdgeInsets.only(top: 4, bottom: 20), children: rows);
  }

  Widget _hizbTab(AppState s, Pal p, QuranData q, String Function(String, String) L,
      String Function(int) n) {
    final labels = [
      L('بداية الحزب', 'Start'),
      L('ربع', '¼'),
      L('نصف', '½'),
      L('ثلاثة أرباع', '¾'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: 60,
      itemBuilder: (c, i) {
        final h = i + 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Box(
            radius: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(L('الحزب ${arNum(h)}', 'Hizb $h'), size: 15, bold: true),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var k = 0; k < 4; k++)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final id = q.hizbq[(h - 1) * 4 + k];
                      _open(q.pageOf(id), ayah: id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(12)),
                      child: Txt(
                        '${labels[k]} · ${L('ص ${arNum(q.pageOf(q.hizbq[(h - 1) * 4 + k]))}', 'p. ${q.pageOf(q.hizbq[(h - 1) * 4 + k])}')}',
                        size: 12,
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _pagesTab(AppState s, Pal p, QuranData q, String Function(int) n) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 62,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 604,
      itemBuilder: (c, i) {
        final pg = i + 1;
        final cur = pg == _page;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(pg),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cur ? p.sel : p.card,
              borderRadius: BorderRadius.circular(12),
              border: cur ? Border.all(color: p.accent, width: 1.5) : null,
            ),
            child: Txt(n(pg), size: 13, bold: cur),
          ),
        );
      },
    );
  }

  Widget _marksTab(AppState s, Pal p, QuranData q, String Function(String, String) L,
      String Function(int) n) {
    if (_marks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Txt(
            L('لا توجد علامات بعد.\nاضغط على أي آية أثناء القراءة لإضافة علامة.',
                'No bookmarks yet.\nTap any verse while reading to add one.'),
            size: 13,
            color: p.muted,
            align: TextAlign.center,
          ),
        ),
      );
    }
    final list = _marks.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: list.length,
      itemBuilder: (c, k) {
        final id = list[k];
        final su = q.surahOf(id), ay = q.ayahOf(id);
        return _row(
          p,
          lead: n(ay),
          title: L('سورة ${q.names[su - 1]} · آية ${arNum(ay)}', '${q.translit[su - 1]} · verse $ay'),
          sub: _snippet(q.text(id)),
          action: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, color: p.muted, size: 20),
            onPressed: () {
              setState(() => _marks.remove(id));
              _saveMarks();
            },
          ),
          onTap: () => _open(q.pageOf(id), ayah: id),
        );
      },
    );
  }

  Widget _searchTab(AppState s, Pal p, QuranData q, String Function(String, String) L,
      String Function(int) n) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: TextField(
          controller: _textSearch,
          style: TextStyle(color: p.text),
          decoration: fieldDeco(p, L('ابحث في آيات القرآن (أو اكتب ٢:٢٥٥)', 'Search the verses (or type 2:255)')),
          textInputAction: TextInputAction.search,
          onChanged: _search,
          onSubmitted: _search,
        ),
      ),
      if (_hitQ.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Txt(
              _hits.isEmpty
                  ? L('لا توجد نتائج', 'No results')
                  : L('${arNum(_hits.length)} نتيجة${_hits.length >= 100 ? ' (أول ١٠٠)' : ''}',
                      '${_hits.length} results${_hits.length >= 100 ? ' (first 100)' : ''}'),
              size: 12,
              color: p.muted,
            ),
          ),
        ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: _hits.length,
          itemBuilder: (c, k) {
            final id = _hits[k];
            final su = q.surahOf(id), ay = q.ayahOf(id);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _open(q.pageOf(id), ayah: id),
                child: Box(
                  radius: 16,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(L('سورة ${q.names[su - 1]} · آية ${arNum(ay)}', '${q.translit[su - 1]} · verse $ay'),
                        size: 12, bold: true, color: p.accent),
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        q.text(id),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 19, height: 1.9, color: p.text),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------- reader
  Widget _reader(AppState s, Pal p, QuranData q) {
    String L(String ar, String en) => s.rtl ? ar : en;
    final startId = q.page[_page - 1];
    final endId = q.pageEnd(_page);
    final s1 = q.surahOf(startId), s2 = q.surahOf(endId);
    String name(int su) => L('سورة ${q.names[su - 1]}', q.translit[su - 1]);
    final title = s1 == s2 ? name(s1) : '${name(s1)} – ${name(s2)}';
    final hizb = (q.hizbQuarterOf(startId) - 1) ~/ 4 + 1;
    final sub = L('الجزء ${arNum(q.juzOf(startId))} · الحزب ${arNum(hizb)} · صفحة ${arNum(_page)}',
        'Juz ${q.juzOf(startId)} · Hizb $hizb · page $_page');

    return Directionality(
      textDirection: TextDirection.rtl, // the Mushaf always reads right-to-left
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(children: [
            IconButton(
              tooltip: L('الفهرس', 'Index'),
              icon: Icon(Icons.list_rounded, color: p.accent),
              onPressed: () {
                _dwell?.cancel();
                setState(() => _reading = false);
              },
            ),
            Expanded(
              child: Column(children: [
                Txt(title, size: 15, bold: true, maxLines: 1, align: TextAlign.center),
                Txt(sub, size: 11, color: p.muted, maxLines: 1, align: TextAlign.center),
              ]),
            ),
            IconButton(
              tooltip: L('اذهب إلى', 'Go to'),
              icon: Icon(Icons.search_rounded, color: p.muted),
              onPressed: _goDialog,
            ),
            IconButton(
              tooltip: L('حجم الخط', 'Font size'),
              icon: Icon(Icons.text_fields_rounded, color: p.muted),
              onPressed: _fontSheet,
            ),
          ]),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: 604,
            onPageChanged: (i) {
              setState(() {
                _page = i + 1;
                _focus = null;
              });
              _prefs?.setInt('mushaf_page', _page);
              _startDwell();
            },
            itemBuilder: (c, i) => _pageBody(p, q, i + 1),
          ),
        ),
        _todayBar(s, p, q),
      ]),
    );
  }

  /// The bar under the page: what has been read today (pages, verses, where). Tap it for the full log.
  Widget _todayBar(AppState s, Pal p, QuranData q) {
    String L(String ar, String en) => s.rtl ? ar : en;
    String n(int v) => s.rtl ? arNum(v) : '$v';
    final day = QuranDay.of(q, WorshipLog.quranOn(s, DateTime.now()));
    final has = day.pages > 0;
    final line1 = has
        ? L('اليوم: ${pagesText(s, day.pages)} · ${n(day.ayat)} آية',
            'Today: ${pagesText(s, day.pages)} · ${day.ayat} verses')
        : L('لا توجد قراءة مسجّلة اليوم', 'No reading logged today');
    final line2 = has
        ? [for (final r in day.runs) '${runSurahs(q, r, s.rtl)} ${runPages(r, s.rtl)}'].join('  ·  ')
        : L('تُسجَّل الصفحة بعد ${n(_readDwell.inSeconds)} ثانية من بقائها أمامك',
            'A page is logged after ${_readDwell.inSeconds} seconds on screen');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _logSheet(q),
        child: Box(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Icon(Icons.auto_stories_rounded, color: p.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Txt(line1, size: 13, bold: true, maxLines: 1),
                const SizedBox(height: 2),
                Txt(line2, size: 11, color: p.muted, maxLines: 1),
              ]),
            ),
            Icon(Icons.keyboard_arrow_up_rounded, color: p.muted),
          ]),
        ),
      ),
    );
  }

  /// The full log of today's reading (opens from the bar). Tapping a reading jumps to its first page.
  void _logSheet(QuranData q) {
    final s = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: s.pal.bg,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _TodayLogSheet(
        q: q,
        onGo: (pg) {
          Navigator.pop(ctx);
          _jump(pg);
        },
      ),
    );
  }

  Widget _pageBody(Pal p, QuranData q, int pg) {
    final from = q.page[pg - 1], to = q.pageEnd(pg);
    final base = TextStyle(fontFamily: 'AmiriQuran', fontSize: _font, height: 2.15, color: p.text);
    final children = <Widget>[];
    var spans = <InlineSpan>[];

    void flush() {
      if (spans.isEmpty) return;
      children.add(Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        style: base,
      ));
      spans = <InlineSpan>[];
    }

    for (var id = from; id <= to; id++) {
      final su = q.surahOf(id), ay = q.ayahOf(id);
      if (ay == 1) {
        flush();
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(vertical: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.sel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.accent.withOpacity(0.6), width: 1.5),
          ),
          child: Column(children: [
            Text('سورة ${q.names[su - 1]}',
                style: TextStyle(
                    fontFamily: 'Thmanyah',
                    fontWeight: FontWeight.w700,
                    fontSize: _font + 2,
                    height: 1.5,
                    color: p.accent)),
            Text('${q.meccan[su - 1] ? 'مكية' : 'مدنية'} · ${arNum(q.ayat[su - 1].length)} آية',
                style: TextStyle(fontFamily: 'Thmanyah', fontSize: 12, color: p.muted)),
          ]),
        ));
        if (su != 1 && su != 9) {
          children.add(Center(
            child: Text(q.ayat[0][0],
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'AmiriQuran', fontSize: _font, height: 2.0, color: p.text)),
          ));
        }
      }
      final focused = id == _focus;
      final marked = _marks.contains(id);
      spans.add(TextSpan(
        text: '${q.text(id)} ',
        recognizer: _recFor(id),
        style: focused ? TextStyle(backgroundColor: p.sel) : null,
      ));
      spans.add(TextSpan(
        text: '﴿${arNum(ay)}﴾ ',
        style: TextStyle(
          color: marked || focused ? p.accent : p.muted,
          fontWeight: marked ? FontWeight.w700 : FontWeight.w400,
          backgroundColor: focused ? p.sel : null,
        ),
      ));
    }
    flush();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        ...children,
        const SizedBox(height: 8),
        Center(child: Text(arNum(pg), style: TextStyle(color: p.muted, fontSize: 13))),
      ],
    );
  }
}


// ---------------------------------------------------------------- today's reading log (full view)
/// Opens from the bar under the page: totals, every reading of the day (newest first), the surahs and the juz.
class _TodayLogSheet extends StatelessWidget {
  const _TodayLogSheet({required this.q, required this.onGo});
  final QuranData q;
  final void Function(int page) onGo;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    String L(String ar, String en) => s.rtl ? ar : en;
    String n(int v) => s.rtl ? arNum(v) : '$v';
    String clock(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    final today = dateOnly(DateTime.now());
    final d = QuranDay.of(q, WorshipLog.quranOn(s, today));

    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Txt(text, size: 14, bold: true, color: p.accent),
        );

    Widget tile(String value, String label) => Expanded(
          child: Box(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(children: [
              Txt(value, size: 20, bold: true, head: true),
              const SizedBox(height: 2),
              Txt(label, size: 11, color: p.muted, maxLines: 1),
            ]),
          ),
        );

    Widget runCard(QuranRun r) {
      var ayat = 0;
      for (var pg = r.first; pg <= r.last; pg++) {
        ayat += q.ayatOnPage(pg);
      }
      final time = r.startMin == r.endMin ? clock(r.startMin) : '${clock(r.startMin)} – ${clock(r.endMin)}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onGo(r.first),
          child: Box(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
                child: Icon(Icons.auto_stories_rounded, color: p.accent, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Txt(runSurahs(q, r, s.rtl, full: true), size: 14, bold: true, maxLines: 2),
                  const SizedBox(height: 2),
                  Txt(
                    '${runPages(r, s.rtl)} · ${pagesText(s, r.pages)} · ${L('${arNum(ayat)} آية', '$ayat verses')}',
                    size: 12,
                    color: p.muted,
                    maxLines: 2,
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Txt(time, size: 12, color: p.muted),
            ]),
          ),
        ),
      );
    }

    Widget surahRow(int su, int cnt) {
      final total = q.ayat[su - 1].length;
      final f = (cnt / total).clamp(0.0, 1.0).toDouble();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Box(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Txt(L('سورة ${q.names[su - 1]}', q.translit[su - 1]), size: 13, bold: true, maxLines: 1)),
              Txt(L('${arNum(cnt)} من ${arNum(total)} آية', '$cnt of $total verses'), size: 12, color: p.muted),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: f,
                minHeight: 5,
                backgroundColor: p.card2,
                valueColor: AlwaysStoppedAnimation<Color>(p.accent),
              ),
            ),
          ]),
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
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
            Expanded(child: Txt(L('سجل قراءة اليوم', "Today's reading log"), size: 20, bold: true, head: true)),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: p.muted)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Txt(s.dateLabel(today), size: 12, color: p.muted),
          ),
          if (d.pages == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
              child: Txt(
                L('لم تُسجَّل أي صفحة اليوم بعد.\nكل صفحة تبقى أمامك ${arNum(_readDwell.inSeconds)} ثانية تُحسب مقروءة وتظهر هنا وفي السجل.',
                    'No pages logged today yet.\nEvery page that stays on screen for ${_readDwell.inSeconds} seconds counts as read and shows up here and in History.'),
                size: 13,
                color: p.muted,
                align: TextAlign.center,
              ),
            )
          else ...[
            Row(children: [
              tile(n(d.pages), L('صفحة', 'pages')),
              const SizedBox(width: 8),
              tile(n(d.ayat), L('آية', 'verses')),
              const SizedBox(width: 8),
              tile(n(d.runs.length), d.runs.length == 1 ? L('قراءة', 'reading') : L('قراءات', 'readings')),
            ]),
            section(L('القراءات (الأحدث أولًا)', 'Readings (newest first)')),
            for (final r in d.runs.reversed) runCard(r),
            section(L('السور', 'Surahs')),
            for (final e in d.surahAyat.entries) surahRow(e.key, e.value),
            section(L('الأجزاء', 'Juz')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final j in d.juz)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(12)),
                  child: Txt(L('الجزء ${arNum(j)}', 'Juz $j'), size: 12, bold: true, color: p.accent),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 0),
              child: Txt(
                L('الصفحة تُحسب مقروءة بعد ${arNum(_readDwell.inSeconds)} ثانية أمامك، وتُحسب مرة واحدة في اليوم. اضغط على أي قراءة للانتقال إليها.',
                    'A page counts as read after ${_readDwell.inSeconds} seconds on screen, once a day. Tap a reading to jump to it.'),
                size: 11,
                color: p.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}