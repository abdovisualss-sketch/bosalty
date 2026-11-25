import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state.dart';
import 'ui.dart';

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
    final dayTotals = <DateTime, int>{};
    for (final e in shown) {
      final k = dateOnly(e.key);
      dayTotals[k] = (dayTotals[k] ?? 0) + (e.value['minutes'] as int);
    }

    final rows = <Widget>[];
    DateTime? last;
    for (final e in shown) {
      final day = dateOnly(e.key);
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
            Txt(s.fmtMin(dayTotals[day]!), size: 13, sec: 'history', color: p.muted),
          ]),
        ));
      }
      final x = e.value;
      final hasTask = (x['task_title'] ?? '').toString().isNotEmpty;
      rows.add(SessionRow(
        at: e.key,
        project: x['project'] as String,
        task: hasTask ? x['task_title'] as String : '',
        minutes: x['minutes'] as num,
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StatsGrid(stats: stats),
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
  final target = TextEditingController();
  String cat = projects[0];

  @override
  void dispose() {
    title.dispose();
    target.dispose();
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
              SizedBox(
                width: 90,
                child: TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: p.text),
                  decoration: fieldDeco(p, s.t('target')),
                ),
              ),
              const SizedBox(width: 8),
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
                  if (s.addGoal(title.text, target.text, cat)) {
                    title.clear();
                    target.clear();
                  }
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
  /// Only the app tour passes this (a numbered marker on the +1 button).
  final PinWrap? pin;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final cat = goal['category'] as String;
    final color = p.proj(cat);
    final prog = goal['progress'] as int, tgt = goal['target'] as int;
    final complete = prog >= tgt;
    final gid = goal['id'] as String;
    final linked = s.tasks.where((x) => x['goal'] == gid).toList();
    return Box(
      color: p.tint(cat),
      border: color,
      margin: const EdgeInsets.only(top: 12),
      child: Column(children: [
        Row(children: [
          if (complete) ...[Ic('check', color: color, size: 16), const SizedBox(width: 6)],
          Expanded(child: Txt(goal['title'] as String, size: 15, bold: true, sec: 'goals', color: complete ? color : p.text)),
          ProjectPill(cat, sec: 'goals'),
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => s.deleteGoal(gid),
              icon: Ic('trash', color: p.muted, size: 16)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _Round(label: '−1', bg: p.card, fg: p.text, onTap: () => s.bumpGoal(gid, -1)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: LinearProgressIndicator(
                value: tgt == 0 ? 0.0 : (prog / tgt).clamp(0.0, 1.0).toDouble(),
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: p.track,
                color: color,
              ),
            ),
          ),
          Txt('$prog / $tgt', size: 13, bold: true, sec: 'goals'),
          const SizedBox(width: 10),
          pinOn(pin, 1, _Round(label: '+1', bg: color, fg: p.onProj, onTap: () => s.bumpGoal(gid, 1))),
        ]),
        for (final x in linked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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

class _Round extends StatelessWidget {
  const _Round({required this.label, required this.bg, required this.fg, required this.onTap});
  final String label;
  final Color bg, fg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Txt(label, size: 14, bold: true, sec: 'goals', color: fg),
        ),
      );
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
