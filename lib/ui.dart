import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profile.dart';
import 'state.dart';

// ---------- small building blocks ----------
class Ic extends StatelessWidget {
  const Ic(this.name, {super.key, this.color, this.size = 20});
  final String name;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    final r = c.r * 255, g = c.g * 255, b = c.b * 255, a = c.a;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        0, 0, 0, 0, r,
        0, 0, 0, 0, g,
        0, 0, 0, 0, b,
        a, 0, 0, 0, 0,
      ]),
      child: Image.asset(
        'assets/icons/$name.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Re-colors a brand picture with the app accent colour: bright / coloured parts become the
/// accent, black stays black and transparency is kept. So logos follow the chosen theme colour.
class AccentImage extends StatelessWidget {
  const AccentImage(this.asset, {super.key, this.width, this.height, this.fit});
  final String asset;
  final double? width, height;
  final BoxFit? fit;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).pal.accent;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        c.r, c.r, c.r, 0, 0,
        c.g, c.g, c.g, 0, 0,
        c.b, c.b, c.b, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Image.asset(asset, width: width, height: height, fit: fit, filterQuality: FilterQuality.medium),
    );
  }
}

class Txt extends StatelessWidget {
  const Txt(this.text,
      {super.key, this.size = 13, this.bold = false, this.sec = 'global', this.color,
       this.head = false, this.strike = false, this.align, this.maxLines});
  final String text;
  final double size;
  final bool bold, head, strike;
  final String sec;
  final Color? color;
  final TextAlign? align;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: s.fs(size, sec),
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? s.pal.text,
        decoration: strike ? TextDecoration.lineThrough : null,
        fontFamily: (head && bold) ? 'Thmanyah' : null,
      ),
    );
  }
}

/// Centers a screen and limits its width (wide Windows windows).
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 900});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class Box extends StatelessWidget {
  const Box({super.key, required this.child, this.color, this.radius = 18,
      this.padding = const EdgeInsets.all(14), this.border, this.margin});
  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? border;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: child,
    );
  }
}

class ProjectPill extends StatelessWidget {
  const ProjectPill(this.project, {super.key, this.sec = 'global'});
  final String project;
  final String sec;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final c = p.proj(project);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Ic(projectIcon[project] ?? 'tasks', color: c, size: 14),
        const SizedBox(width: 6),
        Txt(s.pdisp(project), size: 12, bold: true, sec: sec, color: c),
      ]),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip(this.icon, this.text, {super.key, this.on = false});
  final String icon, text;
  final bool on;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: on ? p.accent : p.card, borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Ic(icon, color: on ? Colors.white : p.muted, size: 14),
        const SizedBox(width: 6),
        Txt(text, size: 12, bold: true, sec: 'header', color: on ? Colors.white : p.muted),
      ]),
    );
  }
}

Widget dd<T>(Pal p, {required T value, required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(16)),
    child: DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      dropdownColor: p.card,
      borderRadius: BorderRadius.circular(16),
      iconEnabledColor: p.muted,
    ),
  );
}

InputDecoration fieldDeco(Pal p, String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.muted),
      filled: true,
      fillColor: p.card2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );

// ---------- header: logo + open-tasks chip; everything else lives in Settings ----------
class Header extends StatelessWidget {
  const Header({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final logo = MediaQuery.sizeOf(context).width >= 760 ? 104.0 : 84.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 6),
      child: Row(children: [
        AccentImage('assets/brand/seal.png', width: logo, height: logo),
        const SizedBox(width: 14),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: InfoChip('tasks', '${s.pendingTasks.length}'),
          ),
        ),
        IconButton(
            onPressed: () => showSettings(context),
            tooltip: s.t('settings'),
            icon: Icon(Icons.tune, color: p.muted)),
      ]),
    );
  }
}

// ---------- prayer banner ----------
class PrayerBanner extends StatefulWidget {
  const PrayerBanner({super.key});
  @override
  State<PrayerBanner> createState() => _PrayerBannerState();
}

class _PrayerBannerState extends State<PrayerBanner> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static const _icons = <String, IconData>{
    'fajr': Icons.nights_stay_rounded,
    'dhuhr': Icons.light_mode_rounded,
    'asr': Icons.wb_sunny_outlined,
    'maghrib': Icons.wb_twilight_rounded,
    'isha': Icons.dark_mode_rounded,
  };

  String _until(AppState s, int mins) {
    final h = mins ~/ 60, m = mins % 60;
    final parts = [if (h > 0) '$h${s.t('h')}', if (m > 0 || h == 0) '$m${s.t('m')}'].join(' ');
    return s.rtl ? 'بعد $parts' : 'in $parts';
  }

  Widget _cell(AppState s, String k, double time, bool isNext, bool past, int mins) {
    final p = s.pal;
    final fg = isNext ? p.accent : (past ? p.muted.withOpacity(0.6) : p.text);
    final sub = isNext ? p.accent : (past ? p.muted.withOpacity(0.6) : p.muted);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
      decoration: BoxDecoration(
        color: isNext ? p.sel : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_icons[k], size: 19, color: fg),
        const SizedBox(height: 5),
        Txt(s.t(k), size: 11, bold: true, sec: 'header', color: fg, maxLines: 1),
        const SizedBox(height: 1),
        FittedBox(fit: BoxFit.scaleDown, child: Txt(s.fmtClock(time), size: 11, sec: 'header', color: sub)),
        if (isNext) ...[
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, child: Txt(_until(s, mins), size: 10, bold: true, sec: 'header', color: p.accent)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final now = DateTime.now();
    final times = prayerTimes(dateOnly(now));
    final nowH = now.hour + now.minute / 60;
    String? found;
    for (final k in prayers) {
      if (times[k]! > nowH) {
        found = k;
        break;
      }
    }
    // after Isha the next prayer is tomorrow's Fajr
    final String next = found ?? 'fajr';
    final double nextH = found != null
        ? times[found]!
        : prayerTimes(DateTime(now.year, now.month, now.day + 1))['fajr']! + 24;
    final int mins = ((nextH - nowH) * 60).ceil().clamp(1, 1440).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.muted.withOpacity(0.12)),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final k in prayers)
            Expanded(
              child: _cell(s, k, times[k]!, k == next, times[k]! <= nowH && k != next, mins),
            ),
        ]),
      ),
    );
  }
}

// ---------- settings ----------
void showSettings(BuildContext context) {
  final s = AppScope.of(context);
  if (s.locked) {
    s.toast(s.t('finish_first'));
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: s.pal.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => AppScope(state: s, child: const _SettingsSheet()),
  );
}

/// Four small number boxes for the quick timer buttons (minutes). Saves as soon as all four are valid.
class _PresetFields extends StatefulWidget {
  const _PresetFields({required this.initial, required this.onChanged});
  final List<int> initial;
  final ValueChanged<List<int>> onChanged;
  @override
  State<_PresetFields> createState() => _PresetFieldsState();
}

class _PresetFieldsState extends State<_PresetFields> {
  late final List<TextEditingController> _c = [for (final v in widget.initial) TextEditingController(text: '$v')];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    final l = _c.map((c) => int.tryParse(c.text.trim())).toList();
    if (l.every((v) => v != null && v > 0 && v < 600)) widget.onChanged(l.cast<int>());
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Row(children: [
      for (var i = 0; i < _c.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _c[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _changed(),
            style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 16),
            decoration: fieldDeco(p, '').copyWith(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            ),
          ),
        ),
      ],
    ]);
  }
}

// ---------- settings sheet ----------
/// Small tinted square with an icon, used at the start of every settings row.
class _Badge extends StatelessWidget {
  const _Badge(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: p.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: p.accent),
    );
  }
}

/// A titled card that holds a few related settings rows.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Txt(title, size: 12, bold: true, color: p.muted),
        ),
        Material(
          color: p.card,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 64, color: p.muted.withOpacity(0.12)),
              children[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  String _l(AppState s, String ar, String en) => s.rtl ? ar : en;

  Widget _sw(AppState s, IconData icon, String label, String key) => SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        value: s.settings[key] == true,
        activeColor: s.pal.accent,
        secondary: _Badge(icon),
        title: Txt(label, size: 14),
        onChanged: (v) {
          s.setSetting(key, v);
          if (key == 'default_all_days') s.allDays = v;
        },
      );

  /// One row that picks the text size for the whole app: Small / Normal / Large / XL.
  Widget _textSize(AppState s) {
    final p = s.pal;
    final labels = s.rtl ? const ['صغير', 'عادي', 'كبير', 'أكبر'] : const ['Small', 'Normal', 'Large', 'XL'];
    const vals = [0.9, 1.0, 1.15, 1.3];
    final cur = [for (final k in sections) ((s.settings['font_$k'] as num?)?.toDouble() ?? 1.0)];
    var sel = -1;
    for (var i = 0; i < vals.length; i++) {
      if (cur.every((v) => (v - vals[i]).abs() < 0.01)) sel = i;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _Badge(Icons.text_fields_rounded),
          const SizedBox(width: 16),
          Expanded(child: Txt(_l(s, 'حجم الخط', 'Text size'), size: 14)),
          if (sel < 0)
            Txt(_l(s, 'مخصّص', 'Custom'), size: 12, bold: true, color: p.muted),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            for (var i = 0; i < vals.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    for (final k in sections) {
                      s.setSetting('font_$k', vals[i]);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel == i ? p.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Txt(labels[i], size: 13, bold: true, color: sel == i ? Colors.white : p.muted, maxLines: 1),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  /// Slider for the Quran (Mushaf) reading text size, with a live preview.
  Widget _mushafFont(AppState s) {
    final p = s.pal;
    final v = ((s.settings['mushaf_font'] as num?)?.toDouble() ?? 28.0).clamp(18.0, 48.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _Badge(Icons.menu_book_rounded),
          const SizedBox(width: 16),
          Expanded(child: Txt(_l(s, 'حجم نص المصحف', 'Quran text size'), size: 14)),
          Txt('${v.round()}', size: 12, bold: true, color: p.muted),
        ]),
        Slider(
          value: v,
          min: 18,
          max: 48,
          divisions: 15,
          activeColor: p.accent,
          onChanged: (x) => s.setSetting('mushaf_font', x),
        ),
        Center(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              style: TextStyle(fontFamily: 'AmiriQuran', fontSize: v, height: 1.8, color: p.text),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _accentRow(AppState s) {
    final p = s.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _Badge(Icons.palette_rounded),
          const SizedBox(width: 16),
          Expanded(child: Txt(_l(s, 'اللون الأساسي', 'Main color'), size: 14)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final k in accents.keys)
            GestureDetector(
              onTap: () => s.setSetting('accent', k),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accents[k]![s.dark ? 1 : 0],
                  shape: BoxShape.circle,
                  border: Border.all(color: s.settings['accent'] == k ? p.text : Colors.transparent, width: 3),
                ),
                child: s.settings['accent'] == k ? const Icon(Icons.check_rounded, size: 20, color: Colors.white) : null,
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _presetsRow(AppState s) {
    final p = s.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _Badge(Icons.timer_rounded),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(_l(s, 'أزرار المدة السريعة', 'Quick timer buttons'), size: 14),
              Txt(_l(s, 'المدد بالدقائق اللي بتظهر تحت المؤقت', 'Minutes shown under the timer'), size: 12, color: p.muted),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _PresetFields(
          initial: s.presets,
          onChanged: (l) => s.setSetting('presets', l),
        ),
      ]),
    );
  }

  Widget _slider(AppState s, String label, double value, double min, double max, int div, ValueChanged<double> on) {
    final p = s.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Txt(label, size: 12, color: p.muted),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        divisions: div,
        activeColor: p.accent,
        onChanged: on,
      ),
    ]);
  }

  List<Widget> _advanced(AppState s) {
    final p = s.pal;
    final names = {
      'global': _l(s, 'الخط العام والقوائم', 'General text & menus'),
      'header': _l(s, 'الشريط العلوي ومواقيت الصلاة', 'Top bar & prayer times'),
      'tasks': _l(s, 'عناوين وبطاقات المهام', 'Task cards & titles'),
      'timer': _l(s, 'ساعة المؤقت وأزرارها', 'Timer & its buttons'),
      'history': _l(s, 'شاشة السجل', 'History screen'),
      'goals': _l(s, 'شاشة الأهداف', 'Goals screen'),
    };
    final timerWidth = ((s.settings['timer_width'] as num?)?.toDouble() ?? 420.0);
    return [
      Txt(_l(s, 'موضع لوحة المؤقت (للشاشات العريضة)', 'Timer panel position (wide screens)'), size: 12, color: p.muted),
      const SizedBox(height: 6),
      dd<String>(p, value: s.settings['timer_side'] == 'flipped' ? 'flipped' : 'default',
          onChanged: (v) => s.setSetting('timer_side', v!), items: [
        DropdownMenuItem(value: 'default', child: Txt(s.t('side_default'), size: 13)),
        DropdownMenuItem(value: 'flipped', child: Txt(s.t('side_flipped'), size: 13)),
      ]),
      const SizedBox(height: 10),
      _slider(s, s.t('set_timer_width', {'w': timerWidth.round()}),
          timerWidth, 340, 600, 26,
          (v) => s.setSetting('timer_width', v.roundToDouble())),
      const SizedBox(height: 6),
      Txt(_l(s, 'حجم الخط لكل جزء', 'Text size per part'), size: 13, bold: true),
      const SizedBox(height: 4),
      for (final sec in sections)
        _slider(
          s,
          '${names[sec]}  ·  ${((((s.settings['font_$sec'] as num?)?.toDouble() ?? 1.0) * 100)).round()}%',
          ((s.settings['font_$sec'] as num?)?.toDouble() ?? 1.0),
          0.8,
          1.6,
          16,
          (v) => s.setSetting('font_$sec', double.parse(v.toStringAsFixed(2))),
        ),
    ];
  }

  Widget _expander(BuildContext context, AppState s, {required IconData icon, required String title, String? subtitle, required List<Widget> children}) {
    final p = s.pal;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: p.muted,
        collapsedIconColor: p.muted,
        leading: _Badge(icon),
        title: Txt(title, size: 14),
        subtitle: subtitle == null ? null : Txt(subtitle, size: 12, color: p.muted),
        children: children,
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState s) async {
    final p = s.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Txt(_l(s, 'استعادة الإعدادات الأصلية؟', 'Restore default settings?'), size: 17, bold: true, head: true),
        content: Txt(
          _l(s, 'الألوان والخطوط والتخطيط هترجع لوضعها الأصلي. مهامك وبياناتك مش هتتأثر.',
              'Colors, text sizes and layout go back to the defaults. Your tasks and data are not affected.'),
          size: 14,
          color: p.muted,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Txt(s.t('cancel'), color: p.muted)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Txt(_l(s, 'استعادة', 'Restore'), bold: true, color: Colors.white),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      s.resetSettings();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final name = '${s.profile['name'] ?? ''}'.trim();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
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
            Expanded(child: Txt(s.t('settings'), size: 22, bold: true, head: true)),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: p.muted)),
          ]),

          // ---- look ----
          _Group(title: _l(s, 'المظهر', 'Appearance'), children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              value: s.dark,
              activeColor: p.accent,
              secondary: _Badge(s.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
              title: Txt(_l(s, 'الوضع الداكن', 'Dark mode'), size: 14),
              onChanged: (_) => s.toggleTheme(),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: const _Badge(Icons.language_rounded),
              title: Txt(_l(s, 'اللغة', 'Language'), size: 14),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.swap_horiz_rounded, size: 16, color: p.accent),
                  const SizedBox(width: 6),
                  Txt(s.lang == 'ar' ? 'العربية' : 'English', size: 12, bold: true, color: p.accent),
                ]),
              ),
              onTap: () => s.toggleLang(),
            ),
            _accentRow(s),
            _textSize(s),
            _mushafFont(s),
          ]),

          // ---- focus ----
          _Group(title: _l(s, 'التركيز والمهام', 'Focus & tasks'), children: [
            _presetsRow(s),
            _sw(s, Icons.view_agenda_rounded, _l(s, 'بطاقات المهام المدمجة', 'Compact task cards'), 'compact_tasks'),
            _sw(s, Icons.grid_view_rounded, _l(s, 'إظهار صور المشاريع فوق المهام', 'Project tiles above tasks'), 'show_tiles'),
            _sw(s, Icons.calendar_month_rounded, _l(s, 'عرض مهام كل الأيام', 'Show tasks of all days'), 'default_all_days'),
          ]),

          // ---- prayers & alerts ----
          _Group(title: _l(s, 'الصلاة والتنبيهات', 'Prayer & alerts'), children: [
            _sw(s, Icons.wb_twilight_rounded, _l(s, 'شريط مواقيت الصلاة', 'Prayer times bar'), 'show_prayers'),
            _sw(s, Icons.notifications_active_rounded, _l(s, 'تذكير عند كل صلاة', 'Remind me at every prayer'), 'prayer_alerts'),
            _sw(s, Icons.volume_up_rounded, _l(s, 'صوت عند انتهاء الجلسة', 'Sound when the timer ends'), 'sound'),
            _sw(s, Icons.notifications_rounded, _l(s, 'إشعار عند انتهاء الجلسة', 'Notify when the timer ends'), 'notify'),
          ]),

          // ---- fine tuning (collapsed) ----
          _Group(title: _l(s, 'متقدم', 'Advanced'), children: [
            _expander(
              context,
              s,
              icon: Icons.tune_rounded,
              title: _l(s, 'تخصيص دقيق', 'Fine tuning'),
              subtitle: _l(s, 'أحجام الخطوط وتخطيط شاشة التركيز', 'Text sizes and focus-screen layout'),
              children: _advanced(s),
            ),
          ]),

          // ---- account (collapsed) ----
          _Group(title: _l(s, 'الحساب', 'Account'), children: [
            _expander(
              context,
              s,
              icon: Icons.person_rounded,
              title: _l(s, 'حسابي والملف الشخصي', 'My account & profile'),
              subtitle: name.isEmpty ? null : name,
              children: const [AppSection()],
            ),
          ]),

          const SizedBox(height: 18),
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmReset(context, s),
              icon: Icon(Icons.restart_alt_rounded, size: 18, color: p.muted),
              label: Txt(s.t('set_reset'), size: 13, bold: true, color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}