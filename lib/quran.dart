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
const _fallbackStations = [
  Station('إذاعة القرآن الكريم من القاهرة', 'https://stream.radiojar.com/8s5u5tpdtwzuv'),
  Station('إذاعة تراتيل', 'https://backup.qurango.net/radio/tarateel'),
  Station('إذاعة مشاري العفاسي', 'https://backup.qurango.net/radio/mishary_alafasi'),
];

const _stationsApi = 'https://www.mp3quran.net/api/v3/radios?language=ar';

// ================= controller (one global instance, lives as long as the app) =================
class QuranRadio extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  List<Station> stations = const [];
  Set<String> favorites = {};
  bool showFavoritesOnly = false;
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

  void toggleShowFavoritesOnly() {
    showFavoritesOnly = !showFavoritesOnly;
    notifyListeners();
  }

  void setShowFavorites(bool v) {
    if (showFavoritesOnly == v) return;
    showFavoritesOnly = v;
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
        stations = list;
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
    if (stations.isEmpty) return;
    final i = current == null ? 0 : stations.indexWhere((s) => s.url == current!.url);
    play(stations[((i < 0 ? 0 : i) + d) % stations.length]);
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

/// One of the two tabs above the stations list ("All stations" / "Favorites").
Widget _favTab(AppState s,
    {required IconData icon, required String label, required bool on, required VoidCallback onTap, bool heart = false}) {
  final p = s.pal;
  final fg = on ? (heart ? Colors.redAccent : p.accent) : p.muted;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: on ? p.sel : p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: on ? fg : Colors.transparent, width: 2),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Flexible(child: Txt(label, size: 13, bold: true, color: fg, maxLines: 1)),
      ]),
    ),
  );
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
    final displayList = r.showFavoritesOnly
        ? r.stations.where((st) => r.isFavorite(st.url)).toList()
        : r.stations;

    final favCount = r.stations.where((st) => r.isFavorite(st.url)).length;

    return [
      Row(children: [
        Expanded(child: Txt(s.t('q_stations'), size: 16, bold: true, head: true)),
        IconButton(
          tooltip: s.t('q_refresh'),
          onPressed: r.loadingList ? null : r.refreshStations,
          icon: r.loadingList
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.refresh_rounded, color: p.muted),
        ),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: _favTab(
            s,
            icon: Icons.radio_rounded,
            label: '${s.rtl ? 'كل الإذاعات' : 'All stations'}  (${r.stations.length})',
            on: !r.showFavoritesOnly,
            onTap: () => r.setShowFavorites(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _favTab(
            s,
            icon: Icons.favorite_rounded,
            label: '${s.rtl ? 'المفضلة' : 'Favorites'}  ($favCount)',
            on: r.showFavoritesOnly,
            onTap: () => r.setShowFavorites(true),
            heart: true,
          ),
        ),
      ]),
      const SizedBox(height: 8),
      if (displayList.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Txt(
              r.showFavoritesOnly
                  ? (s.rtl ? 'لا توجد إذاعات مفضلة بعد. اضغط على القلب بجانب أي إذاعة لتظهر هنا.' : 'No favorite stations yet. Tap the heart next to any station to see it here.')
                  : s.t('q_empty'),
              size: 14,
              color: p.muted,
              align: TextAlign.center,
            ),
          ),
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
                  Expanded(child: Txt(st.name, size: 14, bold: on, maxLines: 2)),
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