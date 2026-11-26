import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mushaf.dart';
import 'state.dart';
import 'strings.dart';
import 'ui.dart';
import 'worship_log.dart';

// ================= History =================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final all = <MapEntry<DateTime, Map<String, dynamic>>>[];
    for (final x in s.sessions) {
      final d = DateTime.tryParse(x['when'] ?? '');
      if (d != null) all.add(MapEntry(d, x));
    }
    final today = dateOnly(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    int total(bool Function(DateTime) f) =>
        all.where((e) => f(dateOnly(e.key))).fold(0, (a, e) => a + (e.value['minutes'] as int));
    final stats = [
      ['today', 'sun', s.fmtMin(total((d) => d == today))],
      ['week', 'history', s.fmtMin(total((d) => !d.isBefore(weekStart)))],
      ['month', 'goals', s.fmtMin(total((d) => d.year == today.year && d.month == today.month))],
      ['total', 'timer', '${all.length}'],
    ];
    var shown = all.where((e) => s.histFilter == 'All' || e.value['project'] == s.histFilter).toList();
    shown.sort((a, b) => b.key.compareTo(a.key));
    // Everything that happened, newest first: focus sessions, and (when "All projects" is shown)
    // the adhkar lists you finished and the Quran you read.
    final entries = <_HistEntry>[
      for (final e in shown)
        _HistEntry(
          e.key,
          e.value['minutes'] as int,
          SessionRow(
            at: e.key,
            project: e.value['project'] as String,
            task: (e.value['task_title'] ?? '').toString().isNotEmpty ? e.value['task_title'] as String : '',
            minutes: e.value['minutes'] as num,
          ),
        ),
      if (s.histFilter == 'All') ..._worshipEntries(s),
    ];
    entries.sort((a, b) => b.at.compareTo(a.at));
    final dayTotals = <DateTime, int>{};
    for (final e in entries) {
      final k = dateOnly(e.at);
      dayTotals[k] = (dayTotals[k] ?? 0) + e.minutes;
    }

    final rows = <Widget>[];
    DateTime? last;
    for (final e in entries) {
      final day = dateOnly(e.at);
      if (day != last) {
        last = day;
        final label = day == today
            ? s.t('today')
            : day == today.subtract(const Duration(days: 1))
                ? s.t('yesterday')
                : s.dateLabel(day);
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Row(children: [
            Expanded(child: Txt(label, size: 15, bold: true, sec: 'history')),
            if (dayTotals[day]! > 0) Txt(s.fmtMin(dayTotals[day]!), size: 13, sec: 'history', color: p.muted),
          ]),
        ));
      }
      rows.add(e.row);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StatsGrid(stats: stats),
        const SizedBox(height: 12),
        const StreakCard(),
        const SizedBox(height: 12),
        Row(children: [
          Txt(s.t('show'), size: 13, sec: 'history', color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: dd<String>(p, value: s.histFilter, onChanged: (v) => s.setHistFilter(v!), items: [
              DropdownMenuItem(value: 'All', child: Txt(s.t('all_projects'), size: 13, sec: 'history')),
              for (final k in s.projectKeysWith(s.histFilter)) projectItem(s, k),
            ]),
          ),
        ]),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Txt(s.t('no_sessions'), size: 14, sec: 'history', color: p.muted, align: TextAlign.center)),
          )
        else
          ...rows,
      ],
    );
  }
}

/// Days in a row + the last 7 days at a glance (focus minutes, adhkar lists finished, Quran pages).
/// A day counts when it has a focus session, a finished adhkar list or a Quran page.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  static const _fire = Color(0xFFF97316);

  Widget _mini(AppState s, IconData icon, String value, String label) {
    final p = s.pal;
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 18, color: p.accent),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Txt(value, size: 14, bold: true, sec: 'history')),
        Txt(label, size: 11, sec: 'history', color: p.muted, maxLines: 1),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final today = dateOnly(DateTime.now());
    final days = WorshipLog.activeDays(s);
    final streak = WorshipLog.streakNow(days, today);
    final best = WorshipLog.streakBest(days);
    final week = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];

    final mins = <DateTime, int>{};
    for (final x in s.sessions) {
      final d = DateTime.tryParse('${x['when'] ?? ''}');
      if (d == null) continue;
      final k = dateOnly(d);
      mins[k] = (mins[k] ?? 0) + (((x['minutes'] as num?) ?? 0).toInt());
    }
    var focus = 0, lists = 0, pages = 0;
    for (final d in week) {
      focus += mins[d] ?? 0;
      pages += WorshipLog.quranOn(s, d).length;
    }
    for (final e in WorshipLog.adhkarEntries(s)) {
      final d = DateTime.tryParse('${e['when'] ?? ''}');
      if (d != null && week.contains(dateOnly(d))) lists++;
    }

    final arDays = const ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    String dayLabel(DateTime d) => s.rtl ? arDays[d.weekday - 1] : kWeekdays['en']![d.weekday - 1];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.muted.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: streak > 0 ? _fire.withOpacity(0.15) : p.sel, shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department_rounded, color: streak > 0 ? _fire : p.muted, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: streak > 0
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Txt('$streak', size: 24, bold: true, sec: 'history'),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Txt(s.rtl ? 'يوم متتالي' : 'day streak', size: 13, sec: 'history', color: p.muted),
                      ),
                    ]),
                    Txt(s.rtl ? 'أفضل سلسلة: $best' : 'Best: $best', size: 12, sec: 'history', color: p.muted),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(s.rtl ? 'ابدأ سلسلتك النهاردة' : 'Start your streak today', size: 15, bold: true, sec: 'history'),
                    Txt(
                      s.rtl ? 'جلسة تركيز أو أذكار أو صفحة قرآن تكفي' : 'A focus session, adhkar or a Quran page is enough',
                      size: 12,
                      sec: 'history',
                      color: p.muted,
                    ),
                  ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final d in week)
            Expanded(
              child: Column(children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Txt(dayLabel(d), size: 11, sec: 'history', color: d == today ? p.accent : p.muted, bold: d == today),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: days.contains(d) ? p.accent : p.card2,
                    border: d == today && !days.contains(d) ? Border.all(color: p.accent, width: 1.5) : null,
                  ),
                  child: days.contains(d) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 14,
                  child: (mins[d] ?? 0) > 0
                      ? FittedBox(fit: BoxFit.scaleDown, child: Txt('${mins[d]}${s.t('m')}', size: 10, sec: 'history', color: p.muted))
                      : null,
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: p.muted.withOpacity(0.12)),
        const SizedBox(height: 10),
        Row(children: [
          _mini(s, Icons.timer_rounded, s.fmtMin(focus), s.rtl ? 'تركيز' : 'Focus'),
          _mini(s, Icons.wb_twilight_rounded, '$lists', s.rtl ? 'أذكار' : 'Adhkar'),
          _mini(s, Icons.menu_book_rounded, '$pages', s.rtl ? 'صفحات' : 'Pages'),
        ]),
        const SizedBox(height: 4),
        Center(child: Txt(s.rtl ? 'آخر ٧ أيام' : 'Last 7 days', size: 11, sec: 'history', color: p.muted)),
      ]),
    );
  }
}

/// One line of the History list (a focus session, an adhkar list, a day of Quran reading).
class _HistEntry {
  const _HistEntry(this.at, this.minutes, this.row);
  final DateTime at;
  final int minutes; // focus minutes (0 for worship lines)
  final Widget row;
}

/// The adhkar lists finished and the Quran read, as simple History lines.
List<_HistEntry> _worshipEntries(AppState s) {
  String L(String ar, String en) => s.rtl ? ar : en;
  final out = <_HistEntry>[];

  for (final x in WorshipLog.adhkarEntries(s)) {
    final at = DateTime.tryParse('${x['when'] ?? ''}');
    if (at == null) continue;
    final kind = '${x['kind']}';
    final cnt = (x['n'] as num?)?.toInt() ?? 0;
    out.add(_HistEntry(
      at,
      0,
      WorshipRow(
        at: at,
        icon: WorshipLog.adhkarIcon(kind),
        color: WorshipLog.adhkarColor(kind),
        title: WorshipLog.adhkarTitle(s, kind),
        detail: cnt > 0
            ? L('أتممتها كاملة · ${arNum(cnt)} ذكر', 'Completed · $cnt adhkar')
            : L('أتممتها كاملة', 'Completed'),
        value: '✓',
      ),
    ));
  }

  final q = QuranData.cached; // null only while the Quran text is still loading
  for (final key in WorshipLog.quranDays(s)) {
    final d = parseDate(key);
    if (d == null) continue;
    final reads = WorshipLog.quranOn(s, d);
    if (reads.isEmpty) continue;
    final lastMin = reads.last.minute;
    final at = DateTime(d.year, d.month, d.day, lastMin ~/ 60, lastMin % 60);
    String detail;
    var pages = reads.length;
    if (q != null) {
      final day = QuranDay.of(q, reads);
      pages = day.pages;
      final names = [for (final su in day.surahAyat.keys) s.rtl ? q.names[su - 1] : q.translit[su - 1]];
      detail = '${names.take(3).join(' · ')}${names.length > 3 ? ' …' : ''} · ${L('${arNum(day.ayat)} آية', '${day.ayat} verses')}';
    } else {
      final nums = [for (final r in reads) r.page]..sort();
      detail = L('ص ${arNum(nums.first)} – ${arNum(nums.last)}', 'p. ${nums.first} – ${nums.last}');
    }
    out.add(_HistEntry(
      at,
      0,
      WorshipRow(
        at: at,
        icon: Icons.auto_stories_rounded,
        color: s.pal.accent,
        title: L('قراءة القرآن', 'Quran reading'),
        detail: detail,
        value: pagesText(s, pages),
      ),
    ));
  }
  return out;
}

/// One worship line in the History list: icon, what it was, a short detail, and the time.
class WorshipRow extends StatelessWidget {
  const WorshipRow({
    super.key,
    required this.at,
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.value,
  });
  final DateTime at;
  final IconData icon;
  final Color color;
  final String title, detail, value;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    return Box(
      color: p.card2,
      radius: 16,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.16), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Txt(title, size: 14, bold: true, sec: 'history', maxLines: 1),
            if (detail.isNotEmpty) Txt(detail, size: 12, sec: 'history', color: p.muted, maxLines: 2),
          ]),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Txt(value, size: 13, bold: true, sec: 'history', color: color),
          Txt('${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
              size: 11, sec: 'history', color: p.muted),
        ]),
      ]),
    );
  }
}

/// The four totals at the top of History: today / this week / this month / number of sessions.
/// [stats] items are [text key, icon name, value]. (The app tour reuses it with example numbers.)
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.stats});
  final List<List<String>> stats;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    return LayoutBuilder(
      builder: (context, c) => GridView.count(
        crossAxisCount: c.maxWidth >= 720 ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          for (final st in stats)
            Box(
              child: Row(children: [
                Ic(st[1], color: p.accent, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Txt(st[2], size: 18, bold: true, head: true, sec: 'history'),
                    Txt(s.t(st[0]), size: 12, sec: 'history', color: p.muted, maxLines: 1),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// One finished focus session in the History list: time, project, task and length.
/// [task] empty = "no specific task". (The app tour reuses it with an example.)
class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.at, required this.project, required this.task, required this.minutes});
  final DateTime at;
  final String project, task;
  final num minutes;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final hasTask = task.isNotEmpty;
    return Box(
      color: p.card2,
      radius: 16,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Txt('${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
            size: 13, sec: 'history', color: p.muted),
        const SizedBox(width: 10),
        ProjectPill(project, sec: 'history'),
        const SizedBox(width: 10),
        Expanded(
            child: Txt(hasTask ? task : s.t('no_task'),
                size: 13, sec: 'history', color: hasTask ? p.text : p.muted, maxLines: 1)),
        Txt(s.fmtMin(minutes), size: 13, bold: true, sec: 'history', color: p.accent),
      ]),
    );
  }
}

// ================= Goals =================
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final title = TextEditingController();
  String cat = projects[0];

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final keys = s.projectKeys;
    if (!keys.contains(cat)) cat = keys.first; // the chosen project was deleted
    final gm = s.goalMonth;
    final goals = s.goalsOfMonth(s.monthKey);
    final done = goals.where((g) => g['progress'] >= g['target']).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(children: [
          IconButton(onPressed: () => s.shiftMonth(-1), icon: Icon(s.rtl ? Icons.chevron_right : Icons.chevron_left, color: p.muted)),
          Expanded(child: Center(child: Txt('${kMonthsOf(s)[gm.month - 1]} ${gm.year}', size: 18, bold: true, head: true, sec: 'goals'))),
          IconButton(onPressed: () => s.shiftMonth(1), icon: Icon(s.rtl ? Icons.chevron_left : Icons.chevron_right, color: p.muted)),
        ]),
        Row(children: [
          Expanded(child: Txt(goals.isEmpty ? '' : s.t('goals_sum', {'d': done, 'n': goals.length}), size: 13, sec: 'goals', color: p.muted)),
          TextButton.icon(
            onPressed: () => showReport(context),
            icon: const Text('📊'),
            label: Txt(s.t('monthly_report'), size: 13, bold: true, sec: 'goals', color: p.accent),
          ),
        ]),
        const SizedBox(height: 6),
        Box(
          child: Column(children: [
            TextField(controller: title, style: TextStyle(color: p.text), decoration: fieldDeco(p, s.t('goal_ph'))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: dd<String>(p, value: cat, onChanged: (v) => setState(() => cat = v!), items: [
                  for (final k in keys) projectItem(s, k),
                ]),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: p.accent, minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                onPressed: () {
                  if (s.addGoal(title.text, '', cat)) title.clear();
                },
                child: const Ic('plus', color: Colors.white, size: 18),
              ),
            ]),
          ]),
        ),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Txt(s.t('no_goals'), size: 14, sec: 'goals', color: p.muted, align: TextAlign.center)),
          )
        else
          for (final g in goals) GoalCard(goal: g),
      ],
    );
  }
}

List<String> kMonthsOf(AppState s) => [for (var i = 1; i <= 12; i++) s.monthName(i)];

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.pin});
  final Map<String, dynamic> goal;
  /// Only the app tour passes this (a numbered marker on the tick).
  final PinWrap? pin;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final cat = goal['category'] as String;
    final color = p.proj(cat);
    final complete = (goal['progress'] as int) >= (goal['target'] as int); // goals are done / not done
    final gid = goal['id'] as String;
    final linked = s.tasks.where((x) => x['goal'] == gid).toList();
    return Box(
      color: p.tint(cat),
      border: color,
      margin: const EdgeInsets.only(top: 12),
      child: Column(children: [
        Row(children: [
          // the tick: tap it to mark the goal done (tap again to undo)
          pinOn(
            pin,
            1,
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => s.toggleGoal(gid),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: complete ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: complete ? Icon(Icons.check_rounded, size: 18, color: p.onProj) : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Txt(goal['title'] as String,
                size: 15, bold: true, sec: 'goals', strike: complete, color: complete ? p.muted : p.text),
          ),
          ProjectPill(cat, sec: 'goals'),
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => s.deleteGoal(gid),
              icon: Ic('trash', color: p.muted, size: 16)),
        ]),
        for (final x in linked)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 46),
            child: Row(children: [
              Ic(x['done'] == true ? 'check' : 'tasks', color: x['done'] == true ? p.accent : p.muted, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Txt('${x['title']}   ${parseDate(x['date'] as String?) == null ? '' : s.dateLabel(parseDate(x['date'] as String?)!)}',
                    size: 12, sec: 'goals', strike: x['done'] == true, color: x['done'] == true ? p.muted : p.text),
              ),
            ]),
          ),
      ]),
    );
  }
}

void showReport(BuildContext context) {
  final s = AppScope.of(context);
  final text = s.monthlyReport();
  showDialog(
    context: context,
    builder: (d) => AppScope(
      state: s,
      child: Builder(builder: (c) {
        final p = s.pal;
        return AlertDialog(
          backgroundColor: p.card,
          title: Txt(s.t('report_title'), size: 18, bold: true, head: true, color: p.accent),
          content: SingleChildScrollView(child: SelectableText(text, style: TextStyle(color: p.text, fontSize: 14, height: 1.6))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Txt(s.t('cancel'), color: p.muted)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.accent),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(d);
                s.toast(s.t('report_copied'));
              },
              child: Txt(s.t('copy_report'), bold: true, color: Colors.white),
            ),
          ],
        );
      }),
    ),
  );
}
