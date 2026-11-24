import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state.dart';
import 'ui.dart';

// ================= data =================
class Dhikr {
  const Dhikr(this.id, this.text, this.count);
  final String id, text;
  final int count;
}

const _kursi =
    'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ';

const _ikhlas =
    'قُلْ هُوَ اللَّهُ أَحَدٌ\nاللَّهُ الصَّمَدُ\nلَمْ يَلِدْ وَلَمْ يُولَدْ\nوَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ';

const _falaq =
    'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ\nمِنْ شَرِّ مَا خَلَقَ\nوَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ\nوَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ\nوَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ';

const _nas =
    'قُلْ أَعُوذُ بِرَبِّ النَّاسِ\nمَلِكِ النَّاسِ\nإِلَهِ النَّاسِ\nمِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ\nالَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ\nمِنَ الْجِنَّةِ وَالنَّاسِ';

const _baqaraEnd =
    'آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ وَقَالُوا سَمِعْنَا وَأَطَعْنَا غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ\nلَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِنْ قَبْلِنَا رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا أَنْتَ مَوْلَانَا فَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ';

const _morning1 =
    'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ';

const _evening1 =
    'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ';

const _morning2 = 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ';
const _evening2 = 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ';

const _sayyid =
    'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ';

const _ishhadMorning =
    'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ';
const _ishhadEvening =
    'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ';

const _nimaMorning =
    'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ';
const _nimaEvening =
    'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ';

const _afini =
    'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ';

const _hasbi = 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ';

const _bismillah =
    'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ';

const _radeetu = 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صلى الله عليه وسلم نَبِيًّا';

const _yaHayy =
    'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ';

const _ilmNafi = 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا';

const _tamat = 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ';

const _tasbih = 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';

const _tahlil =
    'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ';

const _istighfar = 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ';

const _salat = 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ';

const kMorning = <Dhikr>[
  Dhikr('m1', _kursi, 1),
  Dhikr('m2', _ikhlas, 3),
  Dhikr('m3', _falaq, 3),
  Dhikr('m4', _nas, 3),
  Dhikr('m5', _morning1, 1),
  Dhikr('m6', _morning2, 1),
  Dhikr('m7', _sayyid, 1),
  Dhikr('m8', _ishhadMorning, 4),
  Dhikr('m9', _nimaMorning, 1),
  Dhikr('m10', _afini, 3),
  Dhikr('m11', _hasbi, 7),
  Dhikr('m12', _bismillah, 3),
  Dhikr('m13', _radeetu, 3),
  Dhikr('m14', _yaHayy, 1),
  Dhikr('m15', _ilmNafi, 1),
  Dhikr('m16', _tasbih, 100),
  Dhikr('m17', _tahlil, 10),
  Dhikr('m18', _istighfar, 100),
  Dhikr('m19', _salat, 10),
];

const kEvening = <Dhikr>[
  Dhikr('e1', _kursi, 1),
  Dhikr('e2', _ikhlas, 3),
  Dhikr('e3', _falaq, 3),
  Dhikr('e4', _nas, 3),
  Dhikr('e5', _baqaraEnd, 1),
  Dhikr('e6', _evening1, 1),
  Dhikr('e7', _evening2, 1),
  Dhikr('e8', _sayyid, 1),
  Dhikr('e9', _ishhadEvening, 4),
  Dhikr('e10', _nimaEvening, 1),
  Dhikr('e11', _afini, 3),
  Dhikr('e12', _hasbi, 7),
  Dhikr('e13', _bismillah, 3),
  Dhikr('e14', _radeetu, 3),
  Dhikr('e15', _yaHayy, 1),
  Dhikr('e16', _tamat, 3),
  Dhikr('e17', _tasbih, 100),
  Dhikr('e18', _tahlil, 10),
  Dhikr('e19', _istighfar, 100),
  Dhikr('e20', _salat, 10),
];

// ================= storage (inside the app data, so it syncs with the cloud like everything else) =================
// data['adhkar'] = {
//   'day':    'YYYY-MM-DD'      the day the counters belong to (everything resets on a new day)
//   'counts': {id: n}           taps so far today
//   'done':   [ids]             finished today (counter reached its target, or marked done by hand)
//   'fav':    [ids]             hearted built-in adhkar
//   'custom': [ {id, text, count, when: fav|morning|evening|both} ]   adhkar the user added
// }
String _l(AppState s, String ar, String en) => s.rtl ? ar : en;

Map<String, dynamic> _store(AppState s) {
  final cur = s.data['adhkar'];
  if (cur is Map<String, dynamic>) return cur;
  final m = cur is Map ? Map<String, dynamic>.from(cur) : <String, dynamic>{};
  s.data['adhkar'] = m;
  return m;
}

List<String> _strList(Object? v) => v is List ? v.map((e) => '$e').toList() : <String>[];

Map<String, dynamic> _countsMap(Map<String, dynamic> m) {
  final c = m['counts'];
  return c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{};
}

void _rollDay(Map<String, dynamic> m) {
  final today = iso(DateTime.now());
  if (m['day'] != today) {
    m['day'] = today;
    m['done'] = <String>[];
    m['counts'] = <String, dynamic>{};
  }
}

Set<String> _doneToday(AppState s) {
  final m = s.data['adhkar'];
  if (m is! Map || m['day'] != iso(DateTime.now())) return <String>{};
  return _strList(m['done']).toSet();
}

Map<String, int> _countsToday(AppState s) {
  final m = s.data['adhkar'];
  if (m is! Map || m['day'] != iso(DateTime.now()) || m['counts'] is! Map) return <String, int>{};
  return {
    for (final e in (m['counts'] as Map).entries) '${e.key}': (e.value is num ? (e.value as num).toInt() : 0),
  };
}

Set<String> _favIds(AppState s) {
  final m = s.data['adhkar'];
  return m is Map ? _strList(m['fav']).toSet() : <String>{};
}

List<Map<String, dynamic>> _customs(AppState s) {
  final m = s.data['adhkar'];
  if (m is! Map || m['custom'] is! List) return const [];
  return [
    for (final e in (m['custom'] as List))
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

/// One tap on the counter (the caller saves). Returns true when this tap finished the dhikr.
bool _tap(AppState s, Dhikr d) {
  final m = _store(s);
  _rollDay(m);
  final done = _strList(m['done']);
  if (done.contains(d.id)) return false;
  final counts = _countsMap(m);
  final n = ((counts[d.id] as num?)?.toInt() ?? 0) + 1;
  counts[d.id] = n;
  m['counts'] = counts;
  if (n >= d.count) {
    done.add(d.id);
    m['done'] = done;
    return true;
  }
  return false;
}

void _complete(AppState s, Dhikr d) {
  final m = _store(s);
  _rollDay(m);
  final done = _strList(m['done']);
  if (!done.contains(d.id)) done.add(d.id);
  m['done'] = done;
  final counts = _countsMap(m);
  counts[d.id] = d.count;
  m['counts'] = counts;
  s.save();
}

void _clearDone(AppState s, Iterable<String> ids) {
  final m = _store(s);
  _rollDay(m);
  final drop = ids.toSet();
  m['done'] = _strList(m['done']).where((e) => !drop.contains(e)).toList();
  final counts = _countsMap(m);
  counts.removeWhere((k, _) => drop.contains(k));
  m['counts'] = counts;
  s.save();
}

void _toggleFav(AppState s, String id) {
  final m = _store(s);
  final l = _strList(m['fav']);
  if (!l.remove(id)) l.add(id);
  m['fav'] = l;
  s.save();
}

void _addCustom(AppState s, String text, int count, String when) {
  final m = _store(s);
  final l = (m['custom'] is List) ? (m['custom'] as List).toList() : <dynamic>[];
  l.add({'id': 'c_${newId()}', 'text': text, 'count': count, 'when': when});
  m['custom'] = l;
  s.save();
}

void _deleteCustom(AppState s, String id) {
  final m = _store(s);
  m['custom'] = (m['custom'] is List)
      ? (m['custom'] as List).where((e) => !(e is Map && e['id'] == id)).toList()
      : <dynamic>[];
  m['fav'] = _strList(m['fav']).where((e) => e != id).toList();
  m['done'] = _strList(m['done']).where((e) => e != id).toList();
  final counts = _countsMap(m);
  counts.remove(id);
  m['counts'] = counts;
  s.save();
}

String _times(AppState s, int n) {
  if (!s.rtl) return n == 1 ? 'Once' : '×$n';
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتان';
  return n <= 10 ? '$n مرات' : '$n مرة';
}

// ================= look & feel =================
const _verse = 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ';

// header gradient of each tab: morning = sunrise, evening = night, favorites = rose
const _heroColors = <List<Color>>[
  [Color(0xFFD97706), Color(0xFFEA580C)],
  [Color(0xFF4338CA), Color(0xFF7C3AED)],
  [Color(0xFFBE123C), Color(0xFFF43F5E)],
];

Color _accentOf(int tab, bool dark) {
  const light = <Color>[Color(0xFFD97706), Color(0xFF4F46E5), Color(0xFFE11D48)];
  const night = <Color>[Color(0xFFFBBF24), Color(0xFF818CF8), Color(0xFFFB7185)];
  return (dark ? night : light)[tab];
}

/// Soft eight-pointed-star pattern (the classic Islamic tile) drawn behind the header.
class _StarPatternPainter extends CustomPainter {
  const _StarPatternPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    const step = 46.0;
    const half = 14.0;
    final sq = Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2);
    var row = 0;
    for (var y = 0.0; y < size.height + step; y += step) {
      final off = row.isEven ? 0.0 : step / 2;
      for (var x = -step; x < size.width + step; x += step) {
        canvas.save();
        canvas.translate(x + off, y);
        canvas.drawRect(sq, paint);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(sq, paint);
        canvas.restore();
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => old.color != color;
}

class _Ornament extends StatelessWidget {
  const _Ornament(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) {
    final line = Container(width: 38, height: 1, color: color.withOpacity(0.35));
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      line,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5)),
          ),
        ),
      ),
      line,
    ]);
  }
}

/// The big round "sebha" button: tap to count, the ring fills up as you go.
class _TasbeehButton extends StatefulWidget {
  const _TasbeehButton({
    required this.s,
    required this.accent,
    required this.count,
    required this.total,
    required this.done,
    required this.onTap,
  });
  final AppState s;
  final Color accent;
  final int count, total;
  final bool done;
  final VoidCallback onTap;
  @override
  State<_TasbeehButton> createState() => _TasbeehButtonState();
}

class _TasbeehButtonState extends State<_TasbeehButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final p = w.s.pal;
    final frac = w.done ? 1.0 : (w.total <= 0 ? 0.0 : (w.count / w.total).clamp(0.0, 1.0).toDouble());
    final Widget center;
    if (w.done) {
      center = const Icon(Icons.check_rounded, color: Colors.white, size: 42);
    } else if (w.total == 1) {
      center = Icon(Icons.touch_app_rounded, color: w.accent, size: 36);
    } else {
      center = Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Txt('${w.count}', key: ValueKey(w.count), size: 26, bold: true, head: true),
        ),
        Txt('/ ${w.total}', size: 11, color: p.muted),
      ]);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: w.done ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: w.done ? null : w.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: SizedBox(
          width: 98,
          height: 98,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: frac),
              duration: const Duration(milliseconds: 220),
              builder: (_, v, __) => SizedBox.expand(
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: w.accent,
                  backgroundColor: w.accent.withOpacity(0.15),
                ),
              ),
            ),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: w.done ? w.accent : w.accent.withOpacity(p.dark ? 0.2 : 0.12),
              ),
              child: Center(child: center),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.s, required this.icon, required this.tooltip, required this.onTap});
  final AppState s;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = s.pal;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.card2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 21, color: onTap == null ? p.muted.withOpacity(0.35) : p.muted),
          ),
        ),
      ),
    );
  }
}

// ================= one dhikr card =================
class _Item {
  const _Item(this.d, {this.tag, this.custom = false});
  final Dhikr d;
  final String? tag;
  final bool custom;
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    super.key,
    required this.s,
    required this.item,
    required this.count,
    required this.done,
    required this.isFav,
    required this.accent,
    required this.onTap,
    required this.onReset,
    required this.onComplete,
    required this.onFav,
    required this.onDelete,
  });
  final AppState s;
  final _Item item;
  final int count;
  final bool done, isFav;
  final Color accent;
  final VoidCallback onTap, onReset, onComplete, onFav, onDelete;

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Txt(text, size: 12, bold: true, color: accent),
      );

  @override
  Widget build(BuildContext context) {
    final p = s.pal;
    final d = item.d;
    final bg = done ? accent.withOpacity(p.dark ? 0.14 : 0.08) : p.card;
    final line = done ? accent.withOpacity(0.55) : accent.withOpacity(p.dark ? 0.25 : 0.2);
    final caption = done
        ? _l(s, 'تم ✓', 'Done ✓')
        : (d.count == 1 ? _l(s, 'اضغط للإتمام', 'Tap to finish') : _l(s, 'اضغط للعدّ', 'Tap to count'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: done ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    _pill(_times(s, d.count)),
                    if (item.tag != null) _pill(item.tag!),
                  ]),
                ),
                if (item.custom)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: s.t('del'),
                    onPressed: onDelete,
                    icon: Ic('trash', color: p.muted, size: 18),
                  )
                else
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _l(s, 'مفضلة', 'Favorite'),
                    onPressed: onFav,
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.redAccent : p.muted,
                      size: 22,
                    ),
                  ),
              ]),
              _Ornament(accent),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  d.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: s.fs(19),
                    height: 2.0,
                    color: done ? p.text.withOpacity(0.55) : p.text,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _MiniBtn(
                  s: s,
                  icon: Icons.restart_alt_rounded,
                  tooltip: _l(s, 'إعادة العدّ', 'Restart'),
                  onTap: (count > 0 || done) ? onReset : null,
                ),
                const SizedBox(width: 22),
                _TasbeehButton(s: s, accent: accent, count: count, total: d.count, done: done, onTap: onTap),
                const SizedBox(width: 22),
                _MiniBtn(
                  s: s,
                  icon: Icons.done_all_rounded,
                  tooltip: _l(s, 'تمّ', 'Mark as done'),
                  onTap: done ? null : onComplete,
                ),
              ]),
              const SizedBox(height: 8),
              Txt(caption, size: 12, bold: done, color: done ? accent : p.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

// ================= screen =================
class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});
  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  // 0 = morning, 1 = evening, 2 = favorites. Opens on the one that fits the time of day.
  int _tab = DateTime.now().hour < 14 ? 0 : 1;
  Timer? _saveTimer;
  AppState? _s;

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _s?.save(); // don't lose the last taps
    }
    super.dispose();
  }

  void _mut(VoidCallback f) {
    f();
    if (mounted) setState(() {});
  }

  /// A tap on the counter: updates instantly, saves a moment later (so fast tapping stays smooth).
  void _tapDhikr(AppState s, Dhikr d) {
    var finished = false;
    _mut(() => finished = _tap(s, d));
    _saveTimer?.cancel();
    if (finished) {
      HapticFeedback.mediumImpact();
      s.save();
    } else {
      HapticFeedback.selectionClick();
      _saveTimer = Timer(const Duration(milliseconds: 500), s.save);
    }
  }

  List<_Item> _items(AppState s) {
    final custom = _customs(s);
    Dhikr dk(Map<String, dynamic> c) => Dhikr('${c['id']}', '${c['text']}', (c['count'] as num?)?.toInt() ?? 1);
    if (_tab == 0 || _tab == 1) {
      final base = _tab == 0 ? kMorning : kEvening;
      final w = _tab == 0 ? 'morning' : 'evening';
      return [
        for (final d in base) _Item(d),
        for (final c in custom)
          if (c['when'] == w || c['when'] == 'both') _Item(dk(c), custom: true),
      ];
    }
    final fav = _favIds(s);
    return [
      for (final d in kMorning)
        if (fav.contains(d.id)) _Item(d, tag: _l(s, 'الصباح', 'Morning')),
      for (final d in kEvening)
        if (fav.contains(d.id)) _Item(d, tag: _l(s, 'المساء', 'Evening')),
      for (final c in custom) _Item(dk(c), custom: true),
    ];
  }

  Future<void> _add(AppState s) async {
    final when = _tab == 0 ? 'morning' : (_tab == 1 ? 'evening' : 'fav');
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddDhikrDialog(initialWhen: when),
    );
    if (r == null || !mounted) return;
    _mut(() => _addCustom(s, r['text'] as String, r['count'] as int, r['when'] as String));
    s.toast(_l(s, 'تمت إضافة الذكر إلى المفضلة', 'Added to your favorites'));
  }

  Future<void> _confirmDelete(AppState s, String id) async {
    final p = s.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Txt(_l(s, 'حذف هذا الذكر؟', 'Delete this dhikr?'), size: 16, bold: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Txt(s.t('cancel'), color: p.muted)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kUrgent),
            child: Txt(s.t('del'), bold: true, color: Colors.white),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _mut(() => _deleteCustom(s, id));
  }

  Widget _tabBtn(AppState s, int i, IconData icon, String label) {
    final p = s.pal;
    final on = _tab == i;
    final c = _heroColors[i][0];
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: on ? c : p.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: on ? [BoxShadow(color: c.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: on ? Colors.white : p.muted),
            const SizedBox(width: 6),
            Flexible(child: Txt(label, size: 13, bold: true, color: on ? Colors.white : p.muted, maxLines: 1)),
          ]),
        ),
      ),
    );
  }

  Widget _hero(AppState s, List<_Item> items, int doneCount, bool anyProgress) {
    final colors = _heroColors[_tab];
    final total = items.length;
    final complete = total > 0 && doneCount == total;
    final title = [
      _l(s, 'أذكار الصباح', 'Morning adhkar'),
      _l(s, 'أذكار المساء', 'Evening adhkar'),
      _l(s, 'أذكاري المفضلة', 'My favorites'),
    ][_tab];
    final icon = [Icons.wb_sunny_rounded, Icons.nightlight_round, Icons.favorite_rounded][_tab];
    final tagline = complete ? _l(s, 'تقبّل الله منك، أتممت أذكارك ✓', 'May Allah accept it. All done ✓') : _verse;

    final addBtn = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _add(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 18, color: colors[0]),
            const SizedBox(width: 4),
            Txt(_l(s, 'إضافة ذكر', 'Add dhikr'), size: 13, bold: true, color: colors[0]),
          ]),
        ),
      ),
    );

    final resetBtn = Tooltip(
      message: _l(s, 'إعادة تعيين الكل', 'Reset all'),
      child: Material(
        color: Colors.white.withOpacity(0.2),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _mut(() => _clearDone(s, items.map((i) => i.d.id))),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.restart_alt_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _StarPatternPainter(Colors.white.withOpacity(0.13)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Flexible(child: Txt(title, size: 21, bold: true, head: true, color: Colors.white, maxLines: 1)),
                ]),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: (!complete || s.rtl) ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    tagline,
                    style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: s.fs(13), height: 1.8),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  addBtn,
                  if (anyProgress) resetBtn,
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 78,
              height: 78,
              child: Stack(alignment: Alignment.center, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: total == 0 ? 0.0 : doneCount / total),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, v, __) => SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),
                if (complete)
                  const Icon(Icons.check_rounded, color: Colors.white, size: 36)
                else
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Txt('$doneCount', size: 21, bold: true, head: true, color: Colors.white),
                    Txt('/ $total', size: 11, color: Colors.white.withOpacity(0.85)),
                  ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _s = s;
    final p = s.pal;
    final items = _items(s);
    final done = _doneToday(s);
    final counts = _countsToday(s);
    final fav = _favIds(s);
    final doneCount = items.where((i) => done.contains(i.d.id)).length;
    final anyProgress = doneCount > 0 || items.any((i) => (counts[i.d.id] ?? 0) > 0);
    final accent = _accentOf(_tab, p.dark);

    return ListView(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 24),
      children: [
        Row(children: [
          _tabBtn(s, 0, Icons.wb_sunny_rounded, _l(s, 'الصباح', 'Morning')),
          _tabBtn(s, 1, Icons.nightlight_round, _l(s, 'المساء', 'Evening')),
          _tabBtn(s, 2, Icons.favorite_rounded, _l(s, 'المفضلة', 'Favorites')),
        ]),
        const SizedBox(height: 14),
        _hero(s, items, doneCount, anyProgress),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
            child: Column(children: [
              Icon(Icons.favorite_border_rounded, size: 52, color: p.muted.withOpacity(0.5)),
              const SizedBox(height: 12),
              Txt(
                _l(s, 'لا توجد أذكار مفضلة بعد. اضغط على القلب بجانب أي ذكر، أو أضف ذكرك بزر «إضافة ذكر».',
                    'No favorites yet. Tap the heart next to any dhikr, or add your own with "Add dhikr".'),
                size: 14,
                color: p.muted,
                align: TextAlign.center,
              ),
            ]),
          )
        else
          for (final it in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DhikrCard(
                key: ValueKey('${_tab}_${it.d.id}'),
                s: s,
                item: it,
                count: counts[it.d.id] ?? 0,
                done: done.contains(it.d.id),
                isFav: fav.contains(it.d.id),
                accent: accent,
                onTap: () => _tapDhikr(s, it.d),
                onReset: () => _mut(() => _clearDone(s, [it.d.id])),
                onComplete: () {
                  HapticFeedback.mediumImpact();
                  _mut(() => _complete(s, it.d));
                },
                onFav: () => _mut(() => _toggleFav(s, it.d.id)),
                onDelete: () => _confirmDelete(s, it.d.id),
              ),
            ),
      ],
    );
  }
}

// ================= "add your own dhikr" dialog =================
class _AddDhikrDialog extends StatefulWidget {
  const _AddDhikrDialog({required this.initialWhen});
  final String initialWhen;
  @override
  State<_AddDhikrDialog> createState() => _AddDhikrDialogState();
}

class _AddDhikrDialogState extends State<_AddDhikrDialog> {
  final _text = TextEditingController();
  final _count = TextEditingController(text: '1');
  late String _when = widget.initialWhen;
  bool _err = false;

  @override
  void dispose() {
    _text.dispose();
    _count.dispose();
    super.dispose();
  }

  void _save() {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _err = true);
      return;
    }
    final n = (int.tryParse(_count.text.trim()) ?? 1).clamp(1, 9999);
    Navigator.pop(context, {'text': t, 'count': n, 'when': _when});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final opts = <MapEntry<String, String>>[
      MapEntry('fav', _l(s, 'مفضلتي فقط', 'Favorites only')),
      MapEntry('morning', _l(s, 'الصباح', 'Morning')),
      MapEntry('evening', _l(s, 'المساء', 'Evening')),
      MapEntry('both', _l(s, 'الصباح والمساء', 'Morning & evening')),
    ];
    return AlertDialog(
      backgroundColor: p.card,
      title: Txt(_l(s, 'إضافة ذكر مفضل', 'Add a favorite dhikr'), size: 18, bold: true, head: true, color: p.accent),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(color: p.text, height: 1.7),
              decoration: fieldDeco(p, _l(s, 'اكتب الذكر هنا...', 'Write the dhikr here...')).copyWith(
                errorText: _err ? _l(s, 'اكتب الذكر أولًا', 'Please write the dhikr first') : null,
              ),
              onChanged: (_) {
                if (_err) setState(() => _err = false);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              style: TextStyle(color: p.text),
              decoration: fieldDeco(p, '').copyWith(
                labelText: _l(s, 'عدد التكرار', 'Repeat count'),
                labelStyle: TextStyle(color: p.muted),
              ),
            ),
            const SizedBox(height: 14),
            Txt(_l(s, 'يظهر أيضًا في', 'Also show in'), size: 12, color: p.muted),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in opts)
                ChoiceChip(
                  label: Txt(o.value, size: 12, bold: true, color: _when == o.key ? p.accent : p.muted),
                  selected: _when == o.key,
                  showCheckmark: false,
                  selectedColor: p.sel,
                  backgroundColor: p.card2,
                  side: BorderSide.none,
                  onSelected: (_) => setState(() => _when = o.key),
                ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Txt(s.t('cancel'), color: p.muted)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.accent),
          onPressed: _save,
          child: Txt(s.t('save'), bold: true, color: Colors.white),
        ),
      ],
    );
  }
}
