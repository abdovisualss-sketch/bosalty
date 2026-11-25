import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';
import 'ui.dart';

// ================= data =================
class Station {
  const Station(this.name, this.url);
  final String name, url;
  Map<String, String> toJson() => {'name': name, 'url': url};
}

/// Used only if the station list cannot be downloaded and nothing is cached yet.
const _egyptRadio = Station('إذاعة القرآن الكريم من القاهرة', 'https://stream.radiojar.com/8s5u5tpdtwzuv');

const _fallbackStations = [
  _egyptRadio,
  Station('إذاعة تراتيل', 'https://backup.qurango.net/radio/tarateel'),
  Station('إذاعة مشاري العفاسي', 'https://backup.qurango.net/radio/mishary_alafasi'),
];

const _stationsApi = 'https://www.mp3quran.net/api/v3/radios?language=ar';

// ================= sorting stations into groups (by their name) =================
// The radio list comes from mp3quran.net, so each station only has a name and a URL.
// These lists decide where a station goes. Edit them freely: add a reciter name, a country...
// Names are compared after removing tashkeel/spaces and unifying أ/إ/آ, ى/ي and ة/ه.

enum StationGroup { official, reciter, other }

class StationKind {
  const StationKind(this.group, {this.egyptian = false, this.mujawwad = false});
  final StationGroup group;
  final bool egyptian; // an Egyptian reciter
  final bool mujawwad; // true = mujawwad, false = murattal (only meaningful for reciters)
}

String _norm(String s) => s
    .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '') // tashkeel + tatweel
    .replaceAll(RegExp('[إأآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'\s+'), '')
    .toLowerCase();

List<String> _k(List<String> words) => [for (final w in words) _norm(w)];

/// Egyptian reciters (a station whose name has any of these goes under "Egyptian").
final _egyptianReciters = _k([
  'عبد الباسط', 'الحصري', 'المنشاوي', 'مصطفى إسماعيل', 'محمد رفعت', 'رفعت', 'علي البنا',
  'الطبلاوي', 'الشعشاعي', 'شعيشع', 'نعينع', 'الشحات', 'عبد العظيم زاهر', 'الفشني',
  'البهتيمي', 'غلوش', 'محمد جبريل', 'السويسي', 'شبيب', 'رزق حبة', 'عبد الحكم',
  'اللاهوني', 'الطاروطي',
]);

/// Reciters known for the mujawwad style, used when the station name does not say "مجود" / "مرتل".
final _mujawwadReciters = _k([
  'رفعت', 'مصطفى إسماعيل', 'الطبلاوي', 'نعينع', 'الشحات', 'عبد العظيم زاهر', 'الشعشاعي',
  'شعيشع', 'الفشني', 'البهتيمي', 'غلوش', 'السويسي', 'شبيب', 'الطاروطي', 'رزق حبة',
]);

/// Well-known reciters from other countries (only used so their radios are never mistaken for an official station).
final _otherReciters = _k([
  'العفاسي', 'المعيقلي', 'السديس', 'الشريم', 'الغامدي', 'الدوسري', 'العجمي', 'الحذيفي',
  'القطامي', 'الشاطري', 'الهذلي', 'البلوشي', 'الجهني',
]);

final _mujawwadTag = _k(['مجود']);
final _murattalTag = _k(['مرتل', 'ترتيل']);
final _reciterWords = _k(['بصوت', 'القارئ', 'قاري', 'المقرئ', 'شيخ']);
final _quranWord = _k(['القرآن الكريم', 'القرءان الكريم']);
final _radioWord = _norm('إذاعة');
final _egyptPlace = RegExp('مصر(?!ي)'); // Egypt, but not "المصري"
final _places = _k([
  'القاهرة', 'من مصر', 'مكة', 'المدينة', 'الحرم', 'السعودية', 'الكويت', 'قطر', 'الإمارات', 'دبي',
  'الشارقة', 'أبوظبي', 'فلسطين', 'القدس', 'غزة', 'الأردن', 'الجزائر', 'المغرب', 'ليبيا',
  'تونس', 'السودان', 'سوريا', 'العراق', 'اليمن', 'البحرين', 'لبنان', 'موريتانيا',
]);

/// Radios that are about something other than a recitation (explanation, adhkar, translation...).
final _topical = _k(['تفسير', 'ترجمة', 'السنة', 'سيرة', 'أذكار', 'أدعية', 'رقية', 'قصص', 'محاضرات']);

/// Mixed-recitation radios (many reciters in one station): neither a reciter nor an original radio.
final _mixed = _k(['تراتيل', 'تلاوات', 'نوادر', 'رواية', 'متنوع', 'منوع']);

StationKind classifyStation(String name) {
  final n = _norm(name);
  bool any(List<String> keys) => keys.any(n.contains);
  final mujTag = any(_mujawwadTag), murTag = any(_murattalTag);
  final egypt = any(_egyptianReciters);
  final reciterHint = egypt || mujTag || murTag || any(_reciterWords) || any(_otherReciters);

  if (!reciterHint) {
    if (any(_topical)) return const StationKind(StationGroup.other);
    if (any(_quranWord) || (n.contains(_radioWord) && (any(_places) || _egyptPlace.hasMatch(n)))) {
      return const StationKind(StationGroup.official);
    }
    if (any(_mixed)) return const StationKind(StationGroup.other);
  }
  // A reciter's radio: "mujawwad" if the name says so (or he is known for it), otherwise "murattal".
  final mujawwad = mujTag || (!murTag && any(_mujawwadReciters));
  return StationKind(StationGroup.reciter, egyptian: egypt || n.contains(_norm('مصر')), mujawwad: mujawwad);
}

// ================= controller (one global instance, lives as long as the app) =================
class QuranRadio extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  List<Station> stations = const [];
  Set<String> favorites = {};
  /// Where the user is: 'home' (the squares) | 'all' | 'reciters' | 'official' | 'fav'.
  String tab = 'home';
  /// Inside 'reciters': 'menu' (the squares) | 'all' | 'egypt' | 'mujawwad' | 'murattal'.
  String reciterKind = 'menu';
  final Map<String, StationKind> _kinds = {};
  Station? current;
  bool loadingList = false, error = false;
  bool _starting = false, _inited = false;
  double volume = 1.0;
  SharedPreferences? _prefs;

  bool get playing => player.playing;
  bool get busy =>
      _starting ||
      (player.playing &&
          (player.processingState == ProcessingState.loading || player.processingState == ProcessingState.buffering));

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _prefs = await SharedPreferences.getInstance();
    _loadCached();
    player.playerStateStream.listen((_) => notifyListeners());
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      error = true;
      notifyListeners();
    });
    notifyListeners();
    refreshStations();
  }

  void _loadCached() {
    try {
      final raw = _prefs?.getString('radio_stations');
      if (raw != null) {
        stations = [
          for (final m in jsonDecode(raw) as List) Station('${m['name']}', '${m['url']}'),
        ];
      }
    } catch (_) {}
    try {
      final favList = _prefs?.getStringList('radio_favorites');
      if (favList != null) {
        favorites = favList.toSet();
      }
    } catch (_) {}
    if (stations.isEmpty) stations = _fallbackStations;
    stations = _withEgypt(stations);
    current = _pickLast();
  }

  bool isFavorite(String url) => favorites.contains(url);

  void toggleFavorite(String url) {
    if (favorites.contains(url)) {
      favorites.remove(url);
    } else {
      favorites.add(url);
    }
    _prefs?.setStringList('radio_favorites', favorites.toList());
    notifyListeners();
  }

  StationKind kindOf(Station s) => _kinds.putIfAbsent('${s.name}|${s.url}', () => classifyStation(s.name));

  bool _isEgyptRadio(Station s) {
    if (s.url == _egyptRadio.url) return true;
    if (kindOf(s).group != StationGroup.official) return false;
    final n = _norm(s.name);
    return n.contains(_norm('القاهرة')) || _egyptPlace.hasMatch(n);
  }

  /// Egypt's Quran radio (Cairo): the one from the list if there is one, otherwise the built-in one.
  Station get egyptRadio {
    for (final s in stations) {
      if (_isEgyptRadio(s)) return s;
    }
    return _egyptRadio;
  }

  /// Egypt's radio is always on the list, even if mp3quran does not return it.
  List<Station> _withEgypt(List<Station> l) => l.any(_isEgyptRadio) ? l : [_egyptRadio, ...l];

  /// The stations that belong to tab [t] (for the reciters tab, narrowed by the filter [k]).
  List<Station> listFor(String t, [String k = 'all']) {
    switch (t) {
      case 'fav':
        return [for (final s in stations) if (isFavorite(s.url)) s];
      case 'official':
        {
          final o = [for (final s in stations) if (kindOf(s).group == StationGroup.official) s];
          return [...o.where(_isEgyptRadio), ...o.where((s) => !_isEgyptRadio(s))]; // Egypt first
        }
      case 'reciters':
        return [
          for (final s in stations)
            if (kindOf(s).group == StationGroup.reciter &&
                (k == 'all' ||
                    (k == 'egypt' && kindOf(s).egyptian) ||
                    (k == 'mujawwad' && kindOf(s).mujawwad) ||
                    (k == 'murattal' && !kindOf(s).mujawwad)))
              s
        ];
      default:
        return stations;
    }
  }

  /// What the list on screen shows right now (next / previous buttons walk through this).
  List<Station> get visible {
    if (tab == 'reciters') return listFor('reciters', reciterKind == 'menu' ? 'all' : reciterKind);
    return tab == 'home' ? stations : listFor(tab);
  }

  bool get canGoBack => tab != 'home';

  void setTab(String t) {
    tab = t;
    reciterKind = 'menu';
    notifyListeners();
  }

  void setReciterKind(String k) {
    reciterKind = k;
    notifyListeners();
  }

  /// One step back: reciters list -> reciters squares -> main squares.
  void back() {
    if (tab == 'reciters' && reciterKind != 'menu') {
      reciterKind = 'menu';
    } else {
      tab = 'home';
      reciterKind = 'menu';
    }
    notifyListeners();
  }

  Station? _pickLast() {
    if (stations.isEmpty) return null;
    final last = _prefs?.getString('radio_last');
    for (final s in stations) {
      if (s.url == last) return s;
    }
    return stations.first;
  }

  Future<List<Station>> _fetch() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await c.getUrl(Uri.parse(_stationsApi));
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(utf8.decoder).join();
      final list = <Station>[];
      for (final m in (jsonDecode(body)['radios'] as List)) {
        final name = '${m['name'] ?? ''}'.trim();
        final url = '${m['url'] ?? ''}'.trim();
        if (name.isNotEmpty && url.startsWith('http')) list.add(Station(name, url));
      }
      // Cairo Quran radio first, then the rest
      int rank(Station s) => (s.name.contains('القاهرة') || s.name.contains('مصر')) ? 0 : 1;
      final idx = {for (var i = 0; i < list.length; i++) list[i].url: i};
      list.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : idx[a.url]!.compareTo(idx[b.url]!);
      });
      return list;
    } finally {
      c.close(force: true);
    }
  }

  Future<void> refreshStations() async {
    loadingList = true;
    notifyListeners();
    try {
      final list = await _fetch();
      if (list.isNotEmpty) {
        stations = _withEgypt(list);
        _prefs?.setString('radio_stations', jsonEncode([for (final s in list) s.toJson()]));
        final keep = current == null ? null : list.where((s) => s.url == current!.url);
        current = (keep != null && keep.isNotEmpty) ? keep.first : _pickLast();
      }
    } catch (_) {}
    if (stations.isEmpty) stations = _fallbackStations;
    current ??= _pickLast();
    loadingList = false;
    notifyListeners();
  }

  /// Always reloads the stream, so after a pause you hear the live broadcast, not old buffered audio.
  Future<void> play([Station? st]) async {
    final s = st ?? current ?? (stations.isNotEmpty ? stations.first : null);
    if (s == null) return;
    current = s;
    error = false;
    _starting = true;
    notifyListeners();
    _prefs?.setString('radio_last', s.url);
    try {
      await player.setAudioSource(AudioSource.uri(
        Uri.parse(s.url),
        tag: MediaItem(id: s.url, title: s.name, artist: 'القرآن الكريم'),
      ));
      unawaited(player.play());
    } catch (_) {
      error = true;
    }
    _starting = false;
    notifyListeners();
  }

  Future<void> pause() async {
    await player.pause();
    notifyListeners();
  }

  void toggle() => player.playing ? pause() : play();

  void _step(int d) {
    var list = visible;
    if (list.isEmpty) list = stations;
    if (list.isEmpty) return;
    final i = current == null ? -1 : list.indexWhere((s) => s.url == current!.url);
    final n = list.length;
    play(list[i < 0 ? (d > 0 ? 0 : n - 1) : (i + d) % n]);
  }

  void next() => _step(1);
  void prev() => _step(-1);

  void setVolume(double v) {
    volume = v;
    player.setVolume(v);
    notifyListeners();
  }
}

final quranRadio = QuranRadio();

// ================= clear CD in a case + tonearm (black / white only) =================
class SpinningDisc extends StatefulWidget {
  const SpinningDisc({super.key, required this.spinning, required this.size, this.accent});
  final bool spinning;
  final double size;
  final Color? accent;
  @override
  State<SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<SpinningDisc> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final AnimationController _arm = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900), value: widget.spinning ? 1.0 : 0.0);

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(SpinningDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning) {
      _arm.forward();
      if (!_c.isAnimating) _c.repeat();
    } else {
      _arm.reverse();
      if (_c.isAnimating) _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _arm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    return Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(sz * 0.05),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _arm]),
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_arm.value);
          return Stack(clipBehavior: Clip.none, children: [
            CustomPaint(size: Size(sz, sz), painter: DiscPainter(_c.value * math.pi * 2)),
            CustomPaint(size: Size(sz, sz), painter: ArmPainter(t)),
          ]);
        },
      ),
    );
  }
}

Paint _line(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..color = c;

class DiscPainter extends CustomPainter {
  DiscPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    final r = s * 0.43;
    const white = Colors.white;

    final plate = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.05));
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141416), Color(0xFF000000)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.center,
          colors: [white.withOpacity(0.10), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(plate, _line(white.withOpacity(0.5), 2));
    canvas.drawRRect(plate.deflate(s * 0.03), _line(white.withOpacity(0.16), 1));
    final tab = RRect.fromLTRBR(0, s * 0.36, s * 0.07, s * 0.62, Radius.circular(s * 0.02));
    canvas.drawRRect(tab, _line(white.withOpacity(0.45), 1.5));
    canvas.drawRRect(tab.deflate(s * 0.012), _line(white.withOpacity(0.18), 1));

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [white.withOpacity(0.03), white.withOpacity(0.10), white.withOpacity(0.05)],
          stops: const [0.2, 0.85, 1.0],
        ).createShader(rect),
    );

    final groove = _line(white.withOpacity(0.05), 0.6);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(c, r * (0.40 + i * 0.025), groove);
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(angle),
          colors: [
            Colors.transparent,
            white.withOpacity(0.16),
            Colors.transparent,
            Colors.transparent,
            white.withOpacity(0.10),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0.0, 0.06, 0.14, 0.5, 0.56, 0.64, 1.0],
        ).createShader(rect),
    );
    final scratch = _line(white.withOpacity(0.14), 0.8);
    for (var i = 0; i < 9; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * (0.52 + 0.045 * i)), angle + i * 1.7, 0.45 + (i % 3) * 0.3,
          false, scratch);
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            white.withOpacity(0.30),
            Colors.transparent,
            Colors.transparent,
            white.withOpacity(0.20),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0.0, 0.07, 0.15, 0.5, 0.57, 0.65, 1.0],
        ).createShader(rect),
    );

    canvas.drawCircle(c, r, _line(white.withOpacity(0.7), 2));
    canvas.drawCircle(c, r * 0.975, _line(white.withOpacity(0.22), 1));
    canvas.drawArc(Rect.fromCircle(center: c.translate(0, r * 0.012), radius: r), 0.1, math.pi - 0.2, false,
        _line(white.withOpacity(0.25), 2.5));

    canvas.drawCircle(c, r * 0.47, _line(white.withOpacity(0.38), 1.4));
    canvas.drawCircle(c, r * 0.42, _line(white.withOpacity(0.2), 1));
    canvas.drawCircle(c, r * 0.37, Paint()..color = white.withOpacity(0.06));
    canvas.drawCircle(c, r * 0.32, Paint()..color = const Color(0xFF060607));
    canvas.drawCircle(c, r * 0.32, _line(white.withOpacity(0.5), 1.5));
    for (var k = 0; k < 4; k++) {
      final a = angle + k * math.pi / 2 + math.pi / 4;
      final pos = c + Offset(math.cos(a), math.sin(a)) * (r * 0.24);
      canvas.drawCircle(pos, r * 0.035, Paint()..color = Colors.black);
      canvas.drawCircle(pos, r * 0.035, _line(white.withOpacity(0.35), 0.9));
    }
    canvas.drawCircle(c, r * 0.15, Paint()..color = Colors.black);
    canvas.drawCircle(c, r * 0.15, _line(white.withOpacity(0.6), 1.6));
  }

  @override
  bool shouldRepaint(DiscPainter o) => o.angle != angle;
}

class ArmPainter extends CustomPainter {
  ArmPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pivot = Offset(s * 0.88, s * 0.13);
    final a = 1.32 + (2.0 - 1.32) * t;
    final d = Offset(math.cos(a), math.sin(a));
    final n = Offset(-d.dy, d.dx);
    final len = s * 0.385;
    final tip = pivot + d * len;
    final ctrl = pivot + d * (len * 0.5) + n * (s * 0.025);
    final lift = 1 - t;
    final path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);

    canvas.drawPath(
      path.shift(Offset(s * 0.01 + s * 0.02 * lift, s * 0.014 + s * 0.025 * lift)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withOpacity(0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 4 * lift),
    );

    canvas.drawLine(
        pivot - d * (s * 0.04),
        pivot - d * (s * 0.10),
        Paint()
          ..strokeWidth = s * 0.04
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF9CA3AF));

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFB6BCC6), Color(0xFFF3F4F6)])
            .createShader(Rect.fromPoints(pivot, tip).inflate(s * 0.03)),
    );

    final pr = Rect.fromCircle(center: pivot, radius: s * 0.045);
    canvas.drawCircle(
        pivot, s * 0.045, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFF6B7280)]).createShader(pr));
    canvas.drawCircle(pivot, s * 0.045, _line(Colors.white.withOpacity(0.6), 1));
    canvas.drawCircle(pivot, s * 0.016, Paint()..color = const Color(0xFF111111));

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(a);
    final shell = RRect.fromRectAndRadius(Rect.fromLTWH(-s * 0.07, -s * 0.016, s * 0.07, s * 0.032), Radius.circular(s * 0.008));
    canvas.drawRRect(shell, Paint()..color = const Color(0xFF2A2A2E));
    canvas.drawRRect(shell, _line(Colors.white.withOpacity(0.7), 1));
    canvas.drawCircle(Offset(s * 0.004, 0), s * 0.008, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArmPainter o) => o.t != t;
}

// ================= screen =================
class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: quranRadio,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
        const pad = EdgeInsets.fromLTRB(16, 8, 16, 24);
        final wide = box.maxWidth >= 700;
        final panel = _panel(s, wide ? 300 : math.min(box.maxWidth - 48, 300));
        final tiles = _tiles(s);
        if (!wide) return ListView(padding: pad, children: [...panel, const SizedBox(height: 18), ...tiles]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 380, child: ListView(padding: pad, children: panel)),
          Expanded(child: ListView(padding: pad, children: tiles)),
        ]);
      }),
    );
  }

  List<Widget> _panel(AppState s, double discSize) {
    final p = s.pal;
    final r = quranRadio;
    final playing = r.playing;
    final busy = r.busy;
    final status = r.error ? s.t('q_error') : busy ? s.t('q_loading') : playing ? s.t('q_live') : s.t('q_paused');
    return [
      Txt(s.t('q_title'), size: 18, bold: true, head: true, color: p.accent, align: TextAlign.center),
      const SizedBox(height: 14),
      Center(child: SpinningDisc(spinning: playing && !busy, size: discSize)),
      const SizedBox(height: 14),
      Txt(r.current?.name ?? '—', size: 18, bold: true, head: true, align: TextAlign.center, maxLines: 2),
      const SizedBox(height: 6),
      Txt(status, size: 13, color: r.error ? kUrgent : p.muted, align: TextAlign.center),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          iconSize: 34,
          onPressed: r.stations.isEmpty ? null : r.prev,
          icon: Icon(s.rtl ? Icons.skip_next_rounded : Icons.skip_previous_rounded, color: p.muted),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: r.toggle,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: p.accent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: p.accent.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(width: 14),
        IconButton(
          iconSize: 34,
          onPressed: r.stations.isEmpty ? null : r.next,
          icon: Icon(s.rtl ? Icons.skip_previous_rounded : Icons.skip_next_rounded, color: p.muted),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Icon(Icons.volume_down_rounded, color: p.muted),
        Expanded(
          child: Slider(
            value: r.volume,
            activeColor: p.accent,
            onChanged: r.setVolume,
          ),
        ),
        Icon(Icons.volume_up_rounded, color: p.muted),
      ]),
    ];
  }

  List<Widget> _tiles(AppState s) {
    final p = s.pal;
    final r = quranRadio;
    final ar = s.rtl;

    String tabName(String t) => t == 'reciters'
        ? (ar ? 'المقرئين' : 'Reciters')
        : t == 'official'
            ? (ar ? 'الإذاعات الأصلية' : 'Official radios')
            : t == 'fav'
                ? (ar ? 'المفضلة' : 'Favorites')
                : t == 'all'
                    ? (ar ? 'كل الإذاعات' : 'All stations')
                    : s.t('q_stations');
    String kindName(String k) => k == 'egypt'
        ? (ar ? 'مصريين' : 'Egyptian')
        : k == 'mujawwad'
            ? (ar ? 'مجوّد' : 'Mujawwad')
            : k == 'murattal'
                ? (ar ? 'مرتّل' : 'Murattal')
                : (ar ? 'الكل' : 'All');

    final inReciterList = r.tab == 'reciters' && r.reciterKind != 'menu';
    final title = inReciterList ? '${tabName('reciters')}  -  ${kindName(r.reciterKind)}' : tabName(r.tab);
    final showSquares = r.tab == 'home' || (r.tab == 'reciters' && r.reciterKind == 'menu');

    Widget square(IconData icon, String label, int count, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.sel, width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
                child: Icon(icon, color: p.accent, size: 28),
              ),
              const SizedBox(height: 10),
              Txt(label, size: 15, bold: true, align: TextAlign.center, maxLines: 2),
              const SizedBox(height: 2),
              Txt('$count ${ar ? 'إذاعة' : 'stations'}', size: 12, color: p.muted, align: TextAlign.center, maxLines: 1),
            ]),
          ),
        );

    Widget grid(List<Widget> kids) => LayoutBuilder(
          builder: (context, c) => GridView.count(
            crossAxisCount: c.maxWidth >= 560 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: kids,
          ),
        );

    // Egypt's Quran radio (Cairo): one tap to listen
    Widget egyptBanner() {
      final eg = r.egyptRadio;
      final live = r.current?.url == eg.url && r.playing;
      return GestureDetector(
        onTap: () => live ? r.pause() : r.play(eg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: p.accent.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(live ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Txt(eg.name, size: 15, bold: true, color: Colors.white, maxLines: 2),
                Txt(ar ? 'إذاعة مصر • بث مباشر' : 'Egypt • Live', size: 12, color: Colors.white70, maxLines: 1),
              ]),
            ),
            Icon(live ? Icons.graphic_eq_rounded : Icons.radio_rounded, color: Colors.white, size: 24),
          ]),
        ),
      );
    }

    String emptyText() {
      switch (r.tab) {
        case 'fav':
          return ar ? 'لا توجد إذاعات مفضلة بعد. اضغط على القلب بجانب أي إذاعة لتظهر هنا.' : 'No favorite stations yet. Tap the heart next to any station to see it here.';
        case 'reciters':
          return ar ? 'لا توجد إذاعات مقرئين في هذا التصنيف الآن. جرّب تحديث الإذاعات.' : 'No reciter stations in this group right now. Try refreshing the stations.';
        case 'official':
          return ar ? 'لم نجد إذاعات أصلية للقرآن الكريم في القائمة الحالية. جرّب تحديث الإذاعات.' : 'No official Quran radios found in the current list. Try refreshing the stations.';
        default:
          return s.t('q_empty');
      }
    }

    // small grey line under a reciter's name: Egyptian • Mujawwad / Murattal
    String tags(Station st) {
      final k = r.kindOf(st);
      return [
        if (k.egyptian) (ar ? 'مصري' : 'Egyptian'),
        k.mujawwad ? (ar ? 'مجوّد' : 'Mujawwad') : (ar ? 'مرتّل' : 'Murattal'),
      ].join('  •  ');
    }

    final header = Row(children: [
      if (r.canGoBack)
        IconButton(
          tooltip: ar ? 'رجوع' : 'Back',
          onPressed: r.back,
          icon: Icon(Icons.arrow_back_rounded, color: p.accent),
        ),
      Expanded(child: Txt(title, size: 16, bold: true, head: true)),
      IconButton(
        tooltip: s.t('q_refresh'),
        onPressed: r.loadingList ? null : r.refreshStations,
        icon: r.loadingList
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.refresh_rounded, color: p.muted),
      ),
    ]);

    if (showSquares) {
      final List<Widget> body;
      if (r.tab == 'home') {
        body = [
          egyptBanner(),
          const SizedBox(height: 14),
          grid([
            square(Icons.record_voice_over_rounded, tabName('reciters'), r.listFor('reciters').length, () => r.setTab('reciters')),
            square(Icons.verified_rounded, tabName('official'), r.listFor('official').length, () => r.setTab('official')),
            square(Icons.favorite_rounded, tabName('fav'), r.listFor('fav').length, () => r.setTab('fav')),
            square(Icons.radio_rounded, tabName('all'), r.stations.length, () => r.setTab('all')),
          ]),
        ];
      } else {
        body = [
          grid([
            square(Icons.flag_rounded, kindName('egypt'), r.listFor('reciters', 'egypt').length, () => r.setReciterKind('egypt')),
            square(Icons.auto_awesome_rounded, kindName('mujawwad'), r.listFor('reciters', 'mujawwad').length, () => r.setReciterKind('mujawwad')),
            square(Icons.menu_book_rounded, kindName('murattal'), r.listFor('reciters', 'murattal').length, () => r.setReciterKind('murattal')),
            square(Icons.groups_rounded, kindName('all'), r.listFor('reciters').length, () => r.setReciterKind('all')),
          ]),
        ];
      }
      return [header, const SizedBox(height: 8), ...body];
    }

    final displayList = r.visible;
    return [
      header,
      const SizedBox(height: 8),
      if (displayList.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(child: Txt(emptyText(), size: 14, color: p.muted, align: TextAlign.center)),
        )
      else
        for (final st in displayList)
          Builder(builder: (context) {
            final on = r.current?.url == st.url;
            final isFav = r.isFavorite(st.url);
            return GestureDetector(
              onTap: () => r.play(st),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? p.sel : p.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? p.accent : Colors.transparent, width: 2),
                ),
                child: Row(children: [
                  Icon(on && r.playing ? Icons.graphic_eq_rounded : Icons.radio_rounded,
                      color: on ? p.accent : p.muted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Txt(st.name, size: 14, bold: on, maxLines: 2),
                      if (r.tab == 'reciters') Txt(tags(st), size: 11, color: p.muted, maxLines: 1),
                    ]),
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.redAccent : p.muted,
                      size: 22,
                    ),
                    onPressed: () => r.toggleFavorite(st.url),
                  ),
                ]),
              ),
            );
          }),
    ];
  }
}
