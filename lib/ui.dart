import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backup.dart';
import 'onboarding.dart';
import 'profile.dart';
import 'city_sheet.dart';
import 'sounds.dart';
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

// ---------- app-tour markers ----------
/// Lets the app tour put its numbered markers on parts of a REAL widget (so the tour pictures are the app's own
/// widgets and always look exactly like the app). In normal use nothing is passed (null) and the widget is drawn as usual.
typedef PinWrap = Widget Function(int n, Widget child);

Widget pinOn(PinWrap? pin, int n, Widget child) => pin == null ? child : pin(n, child);

/// The numbered badge of the tour: drawn on a picture and repeated in the tips list under it.
class NumPin extends StatelessWidget {
  const NumPin(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.card, width: 2)),
      child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1)),
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
        if (s.pHasIcon(project)) ...[
          ProjectAvatar(project, size: 15),
          const SizedBox(width: 6),
        ],
        Txt(s.pdisp(project), size: 12, bold: true, sec: sec, color: c),
      ]),
    );
  }
}

/// Small picture for a project: the image the user chose, or the built-in icon.
/// With no picture it shows nothing (callers write the name), or - with [letter] - the first letter.
class ProjectAvatar extends StatelessWidget {
  const ProjectAvatar(this.project, {super.key, this.size = 16, this.letter = false});
  final String project;
  final double size;
  final bool letter;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final bytes = s.pimage(project);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    if (s.pHasBuiltin(project) && projectIcon.containsKey(project)) {
      return Ic(projectIcon[project]!, color: s.pal.proj(project), size: size);
    }
    if (!letter) return const SizedBox.shrink();
    final name = s.pdisp(project);
    final c = s.pal.proj(project);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
        style: TextStyle(fontFamily: 'Thmanyah', fontWeight: FontWeight.w700, fontSize: size * 0.55, color: c),
      ),
    );
  }
}

/// One entry of a project drop-down (task picker, timer, goals, history): picture (if any) + name.
DropdownMenuItem<String> projectItem(AppState s, String k, {String sec = 'global'}) {
  return DropdownMenuItem<String>(
    value: k,
    child: Row(children: [
      if (s.pHasIcon(k)) ...[
        ProjectAvatar(k, size: 20),
        const SizedBox(width: 8),
      ],
      Expanded(child: Txt(s.pdisp(k), size: 13, sec: sec, bold: true, color: s.pal.proj(k), maxLines: 1)),
    ]),
  );
}

/// The project card above the tasks: the picture and the name under it and a small line under that.
/// With no picture at all, the name itself is written inside the card in the Thmanyah font.
class ProjectTileFace extends StatelessWidget {
  const ProjectTileFace({
    super.key,
    required this.name,
    required this.sub,
    this.asset,
    this.bytes,
    this.color,
    this.selected = false,
  });
  final String name, sub;
  final String? asset; // built-in picture (null = none)
  final Uint8List? bytes; // picture the user chose (null = none)
  final Color? color; // colour of the written name
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final textOnly = bytes == null && asset == null;
    return SizedBox(
      width: 124,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? p.accent : Colors.transparent, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 52,
              child: bytes != null
                  ? ColoredBox(color: p.card2, child: Image.memory(bytes!, fit: BoxFit.contain, gaplessPlayback: true))
                  : asset != null
                      ? AccentImage(asset!, fit: BoxFit.contain)
                      : Container(
                          color: p.card2,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Thmanyah',
                                fontWeight: FontWeight.w700,
                                fontSize: s.fs(20, 'tasks'),
                                color: color ?? p.accent,
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ),
        if (!textOnly) ...[
          const SizedBox(height: 4),
          Txt(name, size: 12, bold: true, sec: 'tasks', color: selected ? p.accent : p.text, maxLines: 1, align: TextAlign.center),
        ] else if (sub.isNotEmpty)
          const SizedBox(height: 4),
        if (sub.isNotEmpty) Txt(sub, size: 11, sec: 'tasks', color: p.muted, maxLines: 1, align: TextAlign.center),
      ]),
    );
  }
}

String _pr(AppState s, String ar, String en) => s.rtl ? ar : en;

/// Edit a project (picture, name, line under the name) - or add a new one when [k] is null.
/// Opened from Settings or by long-pressing a project tile on the Focus screen.
Future<void> showProjectEditor(BuildContext context, AppState s, String? k) => showDialog<void>(
      context: context,
      builder: (_) => AppScope(state: s, child: _ProjectEditor(k: k)),
    );

/// Asks first, then deletes the project. Returns true if it was deleted.
Future<bool> confirmDeleteProject(BuildContext context, AppState s, String k) async {
  final p = s.pal;
  final name = s.pdisp(k);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppScope(
      state: s,
      child: AlertDialog(
        backgroundColor: p.card,
        title: Txt(_pr(s, 'حذف "$name"؟', 'Delete "$name"?'), size: 17, bold: true, head: true),
        content: Txt(
          _pr(s, 'هيتشال من القوائم. المهام والأهداف والجلسات القديمة هتفضل محفوظة ومش هتضيع.',
              'It will be removed from the lists. Old tasks, goals and sessions are kept, nothing is lost.'),
          size: 14,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'), style: TextStyle(color: p.muted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kUrgent, foregroundColor: Colors.white),
            child: Text(s.t('del')),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  return s.deleteProject(k);
}

class _ProjectEditor extends StatefulWidget {
  const _ProjectEditor({required this.k});
  final String? k; // null = a new project
  @override
  State<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<_ProjectEditor> {
  late final TextEditingController _name;
  late final TextEditingController _sub;
  String _img = ''; // base64 png, '' = none
  bool _noImg = false; // the built-in picture was removed: the name is written as text
  String _err = '';
  bool _busy = false, _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final s = AppScope.of(context);
    final k = widget.k;
    _name = TextEditingController(text: k == null ? '' : s.pdisp(k));
    _sub = TextEditingController(text: k == null ? '' : s.psub(k));
    final im = k == null ? null : s.projectMeta(k)['image'];
    _img = im is String ? im : '';
    _noImg = k != null && s.pNoImage(k);
  }

  @override
  void dispose() {
    _name.dispose();
    _sub.dispose();
    super.dispose();
  }

  /// Shrinks the picture to at most 160 px, so it stays small inside the synced data.
  static Future<String?> _shrink(Uint8List bytes) async {
    const maxSide = 160;
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final desc = await ui.ImageDescriptor.encoded(buffer);
      try {
        final w = desc.width, h = desc.height;
        if (w <= 0 || h <= 0) return null;
        final scale = math.min(1.0, maxSide / math.max(w, h));
        final codec = await desc.instantiateCodec(
          targetWidth: math.max(1, (w * scale).round()),
          targetHeight: math.max(1, (h * scale).round()),
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        codec.dispose();
        if (data == null) return null;
        return base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      } finally {
        desc.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  Future<void> _pick(AppState s) async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final bytes = await BackupFiles.pickImageBytes();
      if (bytes != null) {
        final b64 = await _shrink(bytes);
        if (b64 == null) {
          _err = _pr(s, 'تعذّر قراءة الصورة', 'Could not read that image');
        } else {
          _img = b64;
          _noImg = false;
        }
      }
    } catch (_) {
      _err = _pr(s, 'تعذّر قراءة الصورة. جرّب PNG أو JPG', 'Could not read that image. Try a PNG or JPG');
    }
    if (mounted) setState(() => _busy = false);
  }

  void _save(AppState s) {
    final k = widget.k;
    var name = _name.text.trim();
    if ((k == null || s.isCustomProject(k)) && name.isEmpty) {
      setState(() => _err = _pr(s, 'اكتب اسم التصنيف', 'Write a name'));
      return;
    }
    if (k == null) {
      s.addProject(name: name, sub: _sub.text.trim(), image: _img);
    } else {
      if (name == s.defaultProjectName(k)) name = ''; // same as the built-in name: nothing to store
      s.setProjectMeta(k, name: name, sub: _sub.text.trim(), image: _img, noImage: _noImg);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final k = widget.k;
    final builtin = k != null && !s.isCustomProject(k);
    Uint8List? bytes;
    if (_img.isNotEmpty) {
      try {
        bytes = base64Decode(_img);
      } catch (_) {}
    }
    final showBuiltin = builtin && projectTile.containsKey(k) && !_noImg && _img.isEmpty;
    final asset = showBuiltin ? 'assets/brand/${projectTile[k]}.png' : null;
    final hasPicture = bytes != null || asset != null;
    return AlertDialog(
      backgroundColor: p.card,
      title: Txt(k == null ? _pr(s, 'تصنيف جديد', 'New project') : _pr(s, 'تخصيص المشروع', 'Customize project'),
          size: 18, bold: true, head: true, color: p.accent),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // live preview: exactly how the card will look on the Focus screen
            Center(
              child: ListenableBuilder(
                listenable: Listenable.merge([_name, _sub]),
                builder: (_, __) => ProjectTileFace(
                  name: _name.text.trim(),
                  sub: _sub.text.trim(),
                  asset: asset,
                  bytes: bytes,
                  color: k == null ? p.accent : p.proj(k),
                  selected: true,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(s),
                  icon: const Icon(Icons.image_rounded, size: 18),
                  label: Text(_pr(s, 'اختيار صورة', 'Choose image')),
                  style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: Colors.white),
                ),
              ),
              if (hasPicture) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _img = '';
                            _noImg = true;
                          }),
                  child: Text(_pr(s, 'إزالة الصورة', 'Remove image'), style: TextStyle(color: p.muted)),
                ),
              ],
            ]),
            if (!hasPicture)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Txt(_pr(s, 'من غير صورة هيتكتب الاسم بدلها', 'With no picture the name is written instead'),
                    size: 11, color: p.muted),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              maxLength: 30,
              style: TextStyle(color: p.text),
              decoration: fieldDeco(p, _pr(s, 'اسم المشروع', 'Project name')).copyWith(counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sub,
              maxLength: 40,
              style: TextStyle(color: p.text),
              decoration: fieldDeco(p, _pr(s, 'سطر تحت الاسم (مثال: شركة ديلايت)', 'Line under the name (e.g. Dlight company)'))
                  .copyWith(counterText: ''),
            ),
            if (_err.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Txt(_err, size: 12, color: kUrgent)),
            if (k != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirmDeleteProject(context, s, k);
                  if (ok && mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kUrgent),
                label: Text(_pr(s, 'حذف التصنيف', 'Delete project'), style: const TextStyle(color: kUrgent)),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        if (builtin)
          TextButton(
            onPressed: () {
              s.resetProjectMeta(k!);
              Navigator.pop(context);
            },
            child: Text(_pr(s, 'استعادة الأصل', 'Reset'), style: TextStyle(color: p.muted)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'), style: TextStyle(color: p.muted))),
        FilledButton(
          onPressed: () => _save(s),
          style: FilledButton.styleFrom(backgroundColor: p.accent),
          child: Text(s.t('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
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

// ---------- header: logo + open-tasks chip + help (?) + settings (gear) ----------
/// True while the Mushaf is open in its reading view AND its tab is the visible one
/// (set by MushafScreen). The header hides itself then, so the page gets the whole screen.
final ValueNotifier<bool> mushafReading = ValueNotifier<bool>(false);

class Header extends StatelessWidget {
  const Header({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final logo = MediaQuery.sizeOf(context).width >= 760 ? 104.0 : 84.0;
    return ValueListenableBuilder<bool>(
      valueListenable: mushafReading,
      builder: (context, reading, _) {
        // Hiding on the Mushaf tab is decided in main.dart (s.tab != 5), not by this notifier:
        // the notifier could stay true after leaving the Mushaf and hide the header everywhere.
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
              onPressed: () => Onboarding.show(context),
              tooltip: s.rtl ? 'مساعدة' : 'Help',
              icon: Icon(Icons.help_outline_rounded, color: p.muted),
            ),
            IconButton(
              onPressed: () => showSettings(context),
              tooltip: s.t('settings'),
              icon: Icon(Icons.settings_rounded, color: p.muted),
            ),
          ]),
        );
      },
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
    return s.rtl ? 'متبقي $parts' : '$parts left';
  }

  Widget _chip(AppState s, String k, double time, bool isNext, bool past) {
    final p = s.pal;
    final fg = isNext ? p.accent : (past ? p.muted : p.text);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: isNext ? p.sel : p.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNext ? p.accent.withOpacity(0.7) : Colors.transparent),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (past) ...[Icon(Icons.check_rounded, size: 12, color: p.accent.withOpacity(0.8)), const SizedBox(width: 2)],
            Txt(s.t(k), size: 12.5, bold: true, sec: 'header', color: fg, maxLines: 1),
          ]),
        ),
        const SizedBox(height: 3),
        FittedBox(fit: BoxFit.scaleDown, child: Txt(s.fmtClock(time), size: 12, sec: 'header', color: isNext ? p.accent : (past ? p.muted : p.text.withOpacity(0.85)))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final now = PrayerConfig.now(); // the clock of the chosen city
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

    // where we are between the previous prayer and the next one (for the thin progress line)
    final int idx = prayers.indexOf(next);
    final double prevH = found == null
        ? times['isha']!
        : (idx > 0
            ? times[prayers[idx - 1]]!
            : prayerTimes(DateTime(now.year, now.month, now.day - 1))['isha']! - 24);
    final double frac = nextH <= prevH ? 0.0 : ((nowH - prevH) / (nextH - prevH)).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.muted.withOpacity(0.12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
            child: Icon(_icons[next], color: p.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(s.rtl ? 'الصلاة القادمة' : 'Next prayer', size: 11.5, sec: 'header', color: p.muted),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Txt(s.t(next), size: 19, bold: true, sec: 'header'),
                  const SizedBox(width: 10),
                  Txt(s.fmtClock(nextH), size: 15, bold: true, sec: 'header', color: p.accent),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(20)),
            child: Txt(_until(s, mins), size: 13, bold: true, sec: 'header', color: p.accent, maxLines: 1),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: p.track,
            color: p.accent,
          ),
        ),
        Row(children: [
          for (final k in prayers)
            Expanded(child: _chip(s, k, times[k]!, k == next, times[k]! <= nowH && k != next)),
        ]),
      ]),
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

  /// One project row in Settings: picture + name + the line under it. Tap = edit, bin = delete.
  Widget _projectRow(BuildContext context, AppState s, String k) {
    final p = s.pal;
    final sub = s.psub(k);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: SizedBox(width: 36, height: 36, child: Center(child: ProjectAvatar(k, size: 32, letter: true))),
      title: Txt(s.pdisp(k), size: 14, bold: true, color: p.proj(k)),
      subtitle: sub.isEmpty ? null : Txt(sub, size: 12, color: p.muted),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_rounded, size: 18, color: p.muted),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: _l(s, 'حذف', 'Delete'),
          onPressed: () => confirmDeleteProject(context, s, k),
          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: kUrgent),
        ),
      ]),
      onTap: () => showProjectEditor(context, s, k),
    );
  }

  Widget _addProjectRow(BuildContext context, AppState s) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: const _Badge(Icons.add_rounded),
        title: Txt(_l(s, 'إضافة تصنيف', 'Add project'), size: 14, bold: true, color: s.pal.accent),
        onTap: () => showProjectEditor(context, s, null),
      );

  Widget _restoreProjectsRow(AppState s) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: const _Badge(Icons.restore_rounded),
        title: Txt(_l(s, 'استعادة التصنيفات المحذوفة', 'Restore deleted projects'), size: 14),
        onTap: s.restoreProjects,
      );

  /// Name of the tone that is chosen now (shown under the "Session end tone" row).
  String _toneLabel(AppState s) {
    final t = TimerSounds.byId(s.timerSoundId);
    return t == null ? '' : (s.rtl ? t.ar : t.en);
  }

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

  Widget _tile(AppState s, IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: _Badge(icon),
        title: Txt(title, size: 14),
        subtitle: Txt(sub, size: 12, color: s.pal.muted),
        onTap: onTap,
      );

  bool _blocked(AppState s) {
    if (s.locked) {
      s.toast(s.t('finish_first'));
      return true;
    }
    return false;
  }

  Future<bool> _askRestore(BuildContext context, AppState s, {String? what}) async {
    final p = s.pal;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Txt(_l(s, 'استرجاع النسخة؟', 'Restore this backup?'), size: 18, bold: true, head: true, color: p.accent),
        content: Txt(
            _l(s, 'هيتم استبدال كل بياناتك الحالية${what == null ? '' : ' بنسخة $what'}. ولو غلطت تقدر تتراجع من "التراجع عن آخر استرجاع".',
                'This REPLACES all your current data${what == null ? '' : ' with the copy from $what'}. If it is a mistake you can use "Undo last restore".'),
            size: 14),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Txt(s.t('cancel'), color: p.muted)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Txt(_l(s, 'استرجاع', 'Restore'), bold: true, color: Colors.white),
          ),
        ],
      ),
    );
    return r == true;
  }

  void _restoreResult(AppState s, bool ok) => s.toast(ok
      ? _l(s, 'تم استرجاع النسخة الاحتياطية بنجاح', 'Backup restored successfully')
      : _l(s, 'النسخة غير صالحة ولم يتغير شيء', 'Invalid backup. Nothing was changed'));

  Future<void> _saveFile(BuildContext context, AppState s) async {
    try {
      final ok = await BackupFiles.save(s);
      if (ok) s.toast(_l(s, 'تم حفظ النسخة الاحتياطية', 'Backup file saved'));
    } catch (e) {
      s.toast(_l(s, 'تعذر حفظ الملف. جرّب "نسخ كنص" بدلًا منه.', 'Could not save the file. Try "Copy backup as text" instead.'));
    }
  }

  Future<void> _restoreFile(BuildContext context, AppState s) async {
    if (_blocked(s)) return;
    String? text;
    try {
      text = await BackupFiles.pickText();
    } catch (e) {
      s.toast(_l(s, 'تعذر فتح الملف', 'Could not open the file'));
      return;
    }
    if (text == null || !context.mounted) return;
    if (!await _askRestore(context, s)) return;
    _restoreResult(s, s.importBackupJson(text));
  }

  Future<void> _autoCopies(BuildContext context, AppState s) async {
    if (_blocked(s)) return;
    final p = s.pal;
    final list = s.autoBackups;
    final picked = await showDialog<Map>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Txt(_l(s, 'النسخ التلقائية', 'Automatic copies'), size: 18, bold: true, head: true, color: p.accent),
        content: SizedBox(
          width: 420,
          child: list.isEmpty
              ? Txt(_l(s, 'لا توجد نسخ بعد. هتتعمل أول نسخة تلقائيًا في أول تشغيل بعد وجود بيانات.', 'No copies yet. The first one is made automatically the next time you open the app with some data.'), size: 14, color: p.muted)
              : ListView(shrinkWrap: true, children: [
                  for (final e in list)
                    Builder(builder: (_) {
                      var info = '';
                      try {
                        final d = jsonDecode(e['json'] as String) as Map;
                        info = _l(s, '${(d['tasks'] as List).length} مهمة · ${(d['sessions'] as List).length} جلسة · ${(d['goals'] as List).length} هدف',
                            '${(d['tasks'] as List).length} tasks · ${(d['sessions'] as List).length} sessions · ${(d['goals'] as List).length} goals');
                      } catch (_) {}
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.history_rounded, color: p.accent),
                        title: Txt('${e['day']}', size: 14, bold: true),
                        subtitle: Txt(info, size: 12, color: p.muted),
                        onTap: () => Navigator.pop(ctx, e),
                      );
                    }),
                ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Txt(s.t('cancel'), color: p.muted))],
      ),
    );
    if (picked == null || !context.mounted) return;
    if (!await _askRestore(context, s, what: '${picked['day']}')) return;
    _restoreResult(s, s.importBackupJson(picked['json'] as String));
  }

  Future<void> _undoRestore(BuildContext context, AppState s) async {
    if (_blocked(s)) return;
    final ok = s.undoRestore();
    s.toast(ok
        ? _l(s, 'تم التراجع. رجعت بياناتك كما كانت', 'Undone. Your data is back as it was')
        : _l(s, 'لا توجد نسخة للتراجع', 'Nothing to undo'));
  }

  Future<void> _exportBackup(BuildContext context, AppState s) async {
    final text = s.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: text));
    s.toast(_l(s, 'تم نسخ النسخة الاحتياطية. الصقها في ملاحظات أو واتساب واحتفظ بها.', 'Backup copied. Paste it into a note or chat and keep it safe.'));
  }

  Future<void> _importBackup(BuildContext context, AppState s) async {
    if (_blocked(s)) return;
    final p = s.pal;
    final ctl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: p.card,
          title: Txt(_l(s, 'استرجاع نسخة احتياطية', 'Restore backup'), size: 18, bold: true, head: true, color: p.accent),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Txt(_l(s, 'تحذير: هيتم استبدال كل بياناتك الحالية بالنسخة اللي هتلصقها.', 'Warning: this REPLACES all your current data with the backup you paste.'), size: 13, color: p.muted),
              const SizedBox(height: 10),
              TextField(
                controller: ctl,
                maxLines: 8,
                minLines: 5,
                style: TextStyle(color: p.text, fontSize: 12),
                decoration: fieldDeco(p, _l(s, 'الصق النسخة الاحتياطية هنا', 'Paste the backup here')),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    if (d?.text != null) setD(() => ctl.text = d!.text!);
                  },
                  icon: Icon(Icons.content_paste_rounded, size: 16, color: p.accent),
                  label: Txt(_l(s, 'لصق من الحافظة', 'Paste from clipboard'), size: 13, bold: true, color: p.accent),
                ),
              ),
              if (err != null) Txt(err!, size: 12, color: Colors.redAccent),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Txt(s.t('cancel'), color: p.muted)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.accent),
              onPressed: () {
                if (s.importBackupJson(ctl.text)) {
                  Navigator.pop(ctx, true);
                } else {
                  setD(() => err = _l(s, 'النسخة غير صالحة. تأكد إنك نسخت النص كامل.', 'Invalid backup. Make sure you copied the whole text.'));
                }
              },
              child: Txt(_l(s, 'استرجاع', 'Restore'), bold: true, color: Colors.white),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (ok == true) s.toast(_l(s, 'تم استرجاع النسخة الاحتياطية بنجاح', 'Backup restored successfully'));
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
            _tile(s, Icons.location_city_rounded, _l(s, 'مدينة مواقيت الصلاة', 'Prayer times city'), s.cityLabel,
                () => showCitySheet(context)),
            _sw(s, Icons.notifications_active_rounded, _l(s, 'تذكير عند كل صلاة', 'Remind me at every prayer'), 'prayer_alerts'),
            _sw(s, Icons.wb_sunny_rounded, _l(s, 'تذكير بأذكار الصباح', 'Morning adhkar reminder'), 'adhkar_morning_alert'),
            _sw(s, Icons.nightlight_round, _l(s, 'تذكير بأذكار المساء', 'Evening adhkar reminder'), 'adhkar_evening_alert'),
            _sw(s, Icons.volume_up_rounded, _l(s, 'صوت عند انتهاء الجلسة', 'Sound when the timer ends'), 'sound'),
            _tile(s, Icons.music_note_rounded, _l(s, 'رنّة نهاية الجلسة', 'Session end tone'), _toneLabel(s),
                () => showTimerSoundSheet(context)),
            _sw(s, Icons.notifications_rounded, _l(s, 'إشعار عند انتهاء الجلسة', 'Notify when the timer ends'), 'notify'),
          ]),

          // ---- everything else: closed until you open it ----
          _Group(title: _l(s, 'المزيد', 'More'), children: [
            _expander(
              context,
              s,
              icon: Icons.text_fields_rounded,
              title: _l(s, 'حجم الخط والقراءة', 'Text & reading size'),
              children: [_textSize(s), _mushafFont(s)],
            ),
            _expander(
              context,
              s,
              icon: Icons.folder_rounded,
              title: _l(s, 'تصنيف المشاريع', 'Project categories'),
              subtitle: _l(s, '${s.projectKeys.length} تصنيف', '${s.projectKeys.length} projects'),
              children: [
                for (final k in s.projectKeys) _projectRow(context, s, k),
                _addProjectRow(context, s),
                if (s.hasRemovedDefaults) _restoreProjectsRow(s),
              ],
            ),
            _expander(
              context,
              s,
              icon: Icons.tune_rounded,
              title: _l(s, 'تخصيص دقيق', 'Fine tuning'),
              subtitle: _l(s, 'أحجام الخطوط وتخطيط شاشة التركيز', 'Text sizes and focus-screen layout'),
              children: _advanced(s),
            ),
            _expander(
              context,
              s,
              icon: Icons.save_alt_rounded,
              title: _l(s, 'النسخ الاحتياطي', 'Backup'),
              subtitle: _l(s, 'احفظ بياناتك أو استرجعها', 'Save or restore your data'),
              children: [
                _tile(s, Icons.save_alt_rounded, _l(s, 'حفظ نسخة احتياطية كملف', 'Save backup as a file'),
                    _l(s, 'ملف JSON فيه كل بياناتك، احتفظ به في مكان آمن', 'A JSON file with all your data. Keep it somewhere safe'),
                    () => _saveFile(context, s)),
                _tile(s, Icons.copy_rounded, _l(s, 'نسخ النسخة الاحتياطية كنص', 'Copy backup as text'),
                    _l(s, 'ينسخها للحافظة لتلصقها في ملاحظات أو رسالة', 'Copies it to the clipboard to paste in a note or chat'),
                    () => _exportBackup(context, s)),
                _tile(s, Icons.folder_open_rounded, _l(s, 'استرجاع من ملف', 'Restore from a file'),
                    _l(s, 'اختر ملف نسخة احتياطية سبق حفظه', 'Pick a backup file you saved before'),
                    () => _restoreFile(context, s)),
                _tile(s, Icons.content_paste_rounded, _l(s, 'استرجاع من نص', 'Restore from pasted text'),
                    _l(s, 'الصق نص النسخة الاحتياطية', 'Paste the backup text'),
                    () => _importBackup(context, s)),
                _tile(s, Icons.history_rounded, _l(s, 'النسخ التلقائية على الجهاز', 'Automatic copies on this device'),
                    _l(s, 'يحفظ التطبيق نسخة كل يوم لآخر 5 أيام', 'The app keeps one copy per day for the last 5 days'),
                    () => _autoCopies(context, s)),
                if (s.hasUndoRestore)
                  _tile(s, Icons.undo_rounded, _l(s, 'التراجع عن آخر استرجاع', 'Undo last restore'),
                      _l(s, 'يرجّع بياناتك كما كانت قبل الاسترجاع', 'Brings back your data as it was before the restore'),
                      () => _undoRestore(context, s)),
              ],
            ),
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