import 'package:flutter/material.dart';

import 'state.dart';
import 'ui.dart';

/// Opens the list of cities for the prayer times: tap a city to use it, or type your own coordinates.
Future<void> showCitySheet(BuildContext context) {
  final s = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: s.pal.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => AppScope(state: s, child: const CitySheet()),
  );
}

class CitySheet extends StatefulWidget {
  const CitySheet({super.key});
  @override
  State<CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<CitySheet> {
  final _search = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _custom = false;
  String _err = '';
  String _q = '';

  String _l(AppState s, String ar, String en) => s.rtl ? ar : en;

  @override
  void initState() {
    super.initState();
    if (PrayerConfig.city.id == PrayerConfig.customId) {
      _custom = true;
      _lat.text = PrayerConfig.city.lat.toString();
      _lng.text = PrayerConfig.city.lng.toString();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  double? _num(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  void _saveCustom(AppState s) {
    final la = _num(_lat.text), lo = _num(_lng.text);
    if (la == null || lo == null || la < -65 || la > 65 || lo < -180 || lo > 180) {
      setState(() => _err = _l(s, 'اكتب خط العرض (من -65 إلى 65) وخط الطول (من -180 إلى 180) كأرقام', 'Enter latitude (-65 to 65) and longitude (-180 to 180) as numbers'));
      return;
    }
    s.setCustomCity(la, lo);
    Navigator.of(context).pop();
  }

  Widget _cityRow(AppState s, PrayerCity c, bool on) {
    final p = s.pal;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Icon(
        on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: on ? p.accent : p.muted,
      ),
      title: Txt(s.rtl ? c.ar : c.en, size: 14, bold: on, color: on ? p.accent : null, maxLines: 1),
      onTap: () {
        s.setCity(c.id);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final cur = PrayerConfig.city.id;
    final q = _q.trim().toLowerCase();
    final rows = [
      for (final c in kPrayerCities)
        if (q.isEmpty || c.ar.contains(q) || c.en.toLowerCase().contains(q)) c,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 32 + MediaQuery.of(context).viewInsets.bottom),
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
            Expanded(child: Txt(_l(s, 'مدينة مواقيت الصلاة', 'Prayer times city'), size: 20, bold: true, head: true)),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: p.muted)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Txt(
              _l(s, 'طريقة الحساب بتتغيّر حسب البلد: ${PrayerConfig.methodLabel(true)} الآن.', 'The calculation method follows the country: now ${PrayerConfig.methodLabel(false)}.'),
              size: 12,
              color: p.muted,
            ),
          ),
          TextField(
            controller: _search,
            style: TextStyle(color: p.text),
            decoration: fieldDeco(p, _l(s, 'ابحث عن مدينة...', 'Search for a city...')).copyWith(
              prefixIcon: Icon(Icons.search_rounded, color: p.muted),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 12),
          Material(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Txt(_l(s, 'مفيش مدينة بالاسم ده. جرّب الإحداثيات من تحت.', 'No city with that name. Try coordinates below.'), size: 13, color: p.muted)),
                  )
                : Column(children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: p.muted.withOpacity(0.12)),
                      _cityRow(s, rows[i], rows[i].id == cur),
                    ],
                  ]),
          ),
          const SizedBox(height: 14),
          Material(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Icon(_custom ? Icons.radio_button_checked_rounded : Icons.my_location_rounded,
                    color: cur == PrayerConfig.customId ? p.accent : p.muted),
                title: Txt(_l(s, 'مكان تاني (إحداثيات)', 'Another place (coordinates)'),
                    size: 14, bold: true, color: p.accent),
                trailing: Icon(_custom ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: p.muted),
                onTap: () => setState(() => _custom = !_custom),
              ),
              if (_custom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(
                      _l(s, 'خد الإحداثيات من خرائط جوجل (اضغط مطوّلًا على المكان). الوقت بيتحسب بتوقيت جهازك.',
                          'Get the coordinates from Google Maps (long-press the place). The time uses your device timezone.'),
                      size: 12,
                      color: p.muted,
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _lat,
                          style: TextStyle(color: p.text),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          textDirection: TextDirection.ltr,
                          decoration: fieldDeco(p, _l(s, 'خط العرض', 'Latitude')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lng,
                          style: TextStyle(color: p.text),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          textDirection: TextDirection.ltr,
                          decoration: fieldDeco(p, _l(s, 'خط الطول', 'Longitude')),
                        ),
                      ),
                    ]),
                    if (_err.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Txt(_err, size: 12, color: kUrgent),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: p.accent),
                        onPressed: () => _saveCustom(s),
                        child: Txt(_l(s, 'استخدم هذا المكان', 'Use this place'), bold: true, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
