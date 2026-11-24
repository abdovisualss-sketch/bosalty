import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'state.dart';
import 'ui.dart';

String monthKeyOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

Future<DateTime?> pickDate(BuildContext context, DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

// قائمة مستويات الاستعجال
const List<String> urgencyLevels = ['مستعجل', 'متوسط', 'سهل', 'فكرة'];

Color getUrgencyColor(String urgency) {
  switch (urgency) {
    case 'مستعجل':
      return Colors.redAccent;
    case 'متوسط':
      return Colors.orangeAccent;
    case 'سهل':
      return Colors.green;
    case 'فكرة':
      return Colors.amber;
    default:
      return Colors.blue;
  }
}

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  void _showIdeasCollector(BuildContext context, AppState s) {
    final p = s.pal;
    final ideas = s.tasks.where((t) => t['urgency'] == 'فكرة').toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Txt('مجمع الأفكار', size: 18, bold: true, head: true),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            if (ideas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Txt('لا توجد أفكار مسجلة حتى الآن', color: Colors.grey),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ideas.length,
                  itemBuilder: (c, i) {
                    final idea = ideas[i];
                    return ListTile(
                      leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                      title: Txt(idea['title'] as String? ?? '', size: 15, bold: true),
                      subtitle: Txt(idea['project'] as String? ?? '', size: 12, color: p.muted),
                      trailing: IconButton(
                        icon: Ic('trash', color: p.muted, size: 18),
                        onPressed: () {
                          s.deleteTask(idea['id'] as String);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final list = s.visibleTasks();
    final spent = s.spentByTask();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const TimerCard(),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Txt(s.t('tasks'), size: 18, bold: true, head: true, sec: 'tasks'),
            // أيقونة مجمع الأفكار في الأعلى
            IconButton(
              onPressed: () => _showIdeasCollector(context, s),
              tooltip: 'مجمع الأفكار',
              icon: const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const AddTaskCard(),
        const SizedBox(height: 10),
        const DayBar(),
        const SizedBox(height: 8),
        const ProjectFilter(),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Txt(s.t('no_tasks'), size: 14, sec: 'tasks', color: p.muted, align: TextAlign.center)),
          )
        else
          for (final t in list) TaskCard(task: t, minutes: spent[t['id']] ?? 0),
      ],
    );
  }
}

// ---------- timer ----------
class RingPainter extends CustomPainter {
  RingPainter(this.frac, this.color, this.track);
  final double frac;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    const w = 14.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = track;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * math.max(0.005, frac), false, arc);
  }

  @override
  bool shouldRepaint(RingPainter o) => o.frac != frac || o.color != color || o.track != track;
}

class TimerCard extends StatelessWidget {
  const TimerCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final m = s.remaining ~/ 60, sec = s.remaining % 60;
    final state = s.running ? 'running' : (s.remaining < s.total ? 'paused' : 'ready');
    final open = s.tasks.where((x) => x['project'] == s.timerProject && x['done'] != true).toList();
    final selected = open.any((x) => x['id'] == s.selectedId) ? s.selectedId : null;
    final started = s.remaining < s.total;
    return Box(
      radius: 26,
      child: Column(children: [
        Row(children: [
          Ic('timer', color: p.accent, size: 22),
          const SizedBox(width: 8),
          Txt(s.t('timer'), size: 18, bold: true, head: true, sec: 'timer'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: dd<String>(
              p,
              value: s.timerProject,
              onChanged: s.locked ? null : (v) => s.setTimerProject(v!),
              items: [
                for (final k in projects)
                  DropdownMenuItem(value: k, child: Txt(s.pdisp(k), size: 13, sec: 'timer', color: p.proj(k), bold: true)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: dd<String?>(
              p,
              value: selected,
              onChanged: s.locked ? null : (v) => s.setTimerTask(v),
              items: [
                DropdownMenuItem<String?>(value: null, child: Txt(s.t('no_task'), size: 13, sec: 'timer', color: p.muted, maxLines: 1)),
                for (final x in open)
                  DropdownMenuItem<String?>(value: x['id'] as String, child: Txt(x['title'] as String, size: 13, sec: 'timer', maxLines: 1)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: 230,
          height: 230,
          child: CustomPaint(
            painter: RingPainter(s.total == 0 ? 0 : s.remaining / s.total, p.accent, p.track),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Txt('${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
                    size: 48, bold: true, head: true, sec: 'timer'),
                Txt(s.t(state), size: 13, sec: 'timer', color: p.muted),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Txt(s.t('len'), size: 12, sec: 'timer', color: p.muted),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final mins in s.presets)
            ChoiceChip(
              label: Txt('$mins', size: 14, bold: true, sec: 'timer', color: s.total == mins * 60 ? Colors.white : p.text),
              selected: s.total == mins * 60,
              selectedColor: p.accent,
              backgroundColor: p.card2,
              showCheckmark: false,
              onSelected: s.locked ? null : (_) => s.setMinutes(mins),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: p.accent, minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: s.toggleTimer,
              icon: Ic(s.running ? 'pause' : 'play', color: Colors.white, size: 18),
              label: Txt(s.t(s.running ? 'pause' : (started ? 'resume' : 'start')),
                  size: 15, bold: true, sec: 'timer', color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: BorderSide(color: p.hover),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            onPressed: s.resetTimer,
            icon: Ic('reset', color: p.muted, size: 18),
            label: Txt(s.t('reset'), size: 14, sec: 'timer', color: p.muted),
          ),
        ]),
      ]),
    );
  }
}

// ---------- add task ----------
class AddTaskCard extends StatefulWidget {
  const AddTaskCard({super.key});
  @override
  State<AddTaskCard> createState() => _AddTaskCardState();
}

class _AddTaskCardState extends State<AddTaskCard> {
  final ctl = TextEditingController();
  String project = projects[0];
  String urgency = 'متوسط'; // الخيار الافتراضي للاستعجال
  String? goalId;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _add(AppState s) {
    if (ctl.text.trim().isEmpty) return;
    final xp = urgency == 'مستعجل' ? 30 : (urgency == 'متوسط' ? 20 : (urgency == 'سهل' ? 10 : 5));
    if (s.addTask(ctl.text, project, xp, s.day, goalId)) {
      // حفظ مستوى الاستعجال داخل المهمة
      s.tasks.last['urgency'] = urgency;
      ctl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final monthGoals = s.goalsOfMonth(monthKeyOf(s.day));
    final gid = monthGoals.any((g) => g['id'] == goalId) ? goalId : null;
    return Box(
      child: Column(children: [
        TextField(
          controller: ctl,
          style: TextStyle(color: p.text),
          decoration: fieldDeco(p, s.t('add_ph')),
          onSubmitted: (_) => _add(s),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: dd<String>(p, value: project, onChanged: (v) => setState(() => project = v!), items: [
              for (final k in projects)
                DropdownMenuItem(value: k, child: Txt(s.pdisp(k), size: 13, bold: true, color: p.proj(k), maxLines: 1)),
            ]),
          ),
          const SizedBox(width: 8),
          // منسدلة اختيار مستوى الاستعجال
          Expanded(
            child: dd<String>(p, value: urgency, onChanged: (v) => setState(() => urgency = v!), items: [
              for (final u in urgencyLevels)
                DropdownMenuItem(
                  value: u,
                  child: Txt(u, size: 13, bold: true, color: getUrgencyColor(u), maxLines: 1),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: dd<String?>(p, value: gid, onChanged: (v) => setState(() => goalId = v), items: [
              DropdownMenuItem<String?>(value: null, child: Txt(s.t('no_goal'), size: 13, color: p.muted, maxLines: 1)),
              for (final g in monthGoals)
                DropdownMenuItem<String?>(value: g['id'] as String, child: Txt(g['title'] as String, size: 13, maxLines: 1)),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: p.accent, minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
            onPressed: () => _add(s),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Ic('plus', color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Txt(s.t('add'), bold: true, color: Colors.white),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ---------- day bar / filter ----------
class DayBar extends StatelessWidget {
  const DayBar({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final today = dateOnly(DateTime.now());
    final label = s.allDays
        ? s.t('all_days')
        : s.day == today
            ? s.t('today')
            : s.day == today.subtract(const Duration(days: 1))
                ? s.t('yesterday')
                : s.day == today.add(const Duration(days: 1))
                    ? s.t('tomorrow')
                    : s.dateLabel(s.day);
    return Row(children: [
      IconButton(
          onPressed: () => s.shiftDay(-1),
          icon: Icon(s.rtl ? Icons.chevron_right : Icons.chevron_left, color: p.muted)),
      Expanded(
        child: GestureDetector(
          onTap: () async {
            final d = await pickDate(context, s.day);
            if (d != null) s.setDay(d);
          },
          child: Box(
            color: p.card2,
            radius: 16,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(child: Txt(label, size: 14, bold: true, sec: 'tasks')),
          ),
        ),
      ),
      IconButton(
          onPressed: () => s.shiftDay(1),
          icon: Icon(s.rtl ? Icons.chevron_left : Icons.chevron_right, color: p.muted)),
      TextButton(onPressed: s.goToday, child: Txt(s.t('today'), size: 13, bold: true, color: p.accent)),
      IconButton(
        onPressed: s.toggleAllDays,
        tooltip: s.t('all_days'),
        style: IconButton.styleFrom(backgroundColor: s.allDays ? p.sel : p.card2),
        icon: Ic('globe', color: s.allDays ? p.accent : p.muted, size: 20),
      ),
    ]);
  }
}

class ProjectFilter extends StatelessWidget {
  const ProjectFilter({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final keys = ['All', ...projects];
    if (s.settings['show_tiles'] == true) {
      return SizedBox(
        height: 64,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final k in keys)
            GestureDetector(
              onTap: () => s.setFilter(k),
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: s.filter == k ? p.accent : Colors.transparent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AccentImage('assets/brand/${projectTile[k]}.png', height: 52, fit: BoxFit.cover),
                ),
              ),
            ),
        ]),
      );
    }
    return Wrap(spacing: 8, children: [
      for (final k in keys)
        ChoiceChip(
          label: Txt(s.pdisp(k), size: 12, bold: true, color: s.filter == k ? Colors.white : p.text),
          selected: s.filter == k,
          selectedColor: p.accent,
          backgroundColor: p.card2,
          showCheckmark: false,
          onSelected: (_) => s.setFilter(k),
        ),
    ]);
  }
}

// ---------- task card ----------
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.minutes});
  final Map<String, dynamic> task;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final done = task['done'] == true;
    final id = task['id'] as String;
    final project = task['project'] as String;
    final urgency = (task['urgency'] as String?) ?? 'متوسط';
    final compact = s.settings['compact_tasks'] == true;
    final isSel = s.selectedId == id && !done;
    final d = parseDate(task['date'] as String?);
    String? goalTitle;
    for (final g in s.goals) {
      if (g['id'] == task['goal']) goalTitle = g['title'] as String;
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 6 : 12),
      decoration: BoxDecoration(
        color: isSel ? p.sel : p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isSel ? p.accent : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => s.toggleTaskDone(id),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? p.accent : Colors.transparent,
              border: Border.all(color: done ? p.accent : p.muted, width: 2),
            ),
            child: done ? const Center(child: Ic('check', color: Colors.white, size: 16)) : null,
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Txt(task['title'] as String, size: 15, bold: true, sec: 'tasks', strike: done, color: done ? p.muted : p.text),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ProjectPill(project, sec: 'tasks'),
              // شارة مستوى الاستعجال
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: getUrgencyColor(urgency).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Txt(urgency, size: 10, bold: true, color: getUrgencyColor(urgency)),
              ),
              if (d != null) Txt(s.dateLabel(d), size: 11, sec: 'tasks', color: p.muted),
              if (minutes > 0) Txt(s.fmtMin(minutes), size: 11, sec: 'tasks', color: p.muted),
              if (goalTitle != null) Txt('${s.t('under_goal')}: $goalTitle', size: 11, sec: 'tasks', color: p.muted),
            ]),
          ]),
        ),
        if (!done)
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => s.selectTask(id),
              icon: Ic('play', color: isSel ? p.accent : p.muted, size: 18)),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => editTaskDialog(context, id),
            icon: Icon(Icons.edit_outlined, color: p.muted, size: 20)),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => s.deleteTask(id),
            icon: Ic('trash', color: p.muted, size: 18)),
      ]),
    );
  }
}

void editTaskDialog(BuildContext context, String id) {
  final s = AppScope.of(context);
  final task = s.findTask(id);
  if (task == null) return;
  final ctl = TextEditingController(text: task['title'] as String);
  var project = task['project'] as String;
  var urgency = (task['urgency'] as String?) ?? 'متوسط';
  var date = parseDate(task['date'] as String?) ?? s.day;
  String? goalId = task['goal'] as String?;
  showDialog(
    context: context,
    builder: (dctx) => AppScope(
      state: s,
      child: StatefulBuilder(builder: (c, setSt) {
        final p = s.pal;
        final mg = s.goalsOfMonth(monthKeyOf(date));
        final gid = mg.any((g) => g['id'] == goalId) ? goalId : null;
        return AlertDialog(
          backgroundColor: p.card,
          title: Txt(s.t('edit_task'), size: 18, bold: true, head: true),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ctl, style: TextStyle(color: p.text), decoration: fieldDeco(p, s.t('task'))),
              const SizedBox(height: 10),
              dd<String>(p, value: project, onChanged: (v) => setSt(() => project = v!), items: [
                for (final k in projects)
                  DropdownMenuItem(value: k, child: Txt(s.pdisp(k), size: 13, bold: true, color: p.proj(k))),
              ]),
              const SizedBox(height: 10),
              // تعديل مستوى الاستعجال
              dd<String>(p, value: urgency, onChanged: (v) => setSt(() => urgency = v!), items: [
                for (final u in urgencyLevels)
                  DropdownMenuItem(value: u, child: Txt(u, size: 13, bold: true, color: getUrgencyColor(u))),
              ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await pickDate(c, date);
                  if (d != null) setSt(() => date = dateOnly(d));
                },
                icon: Icon(Icons.calendar_today, size: 18, color: p.muted),
                label: Txt(s.dateLabel(date), size: 13),
              ),
              const SizedBox(height: 10),
              dd<String?>(p, value: gid, onChanged: (v) => setSt(() => goalId = v), items: [
                DropdownMenuItem<String?>(value: null, child: Txt(s.t('no_goal'), size: 13, color: p.muted)),
                for (final g in mg) DropdownMenuItem<String?>(value: g['id'] as String, child: Txt(g['title'] as String, size: 13)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Txt(s.t('cancel'), color: p.muted)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.accent),
              onPressed: () {
                if (ctl.text.trim().isEmpty) {
                  s.toast(s.t('empty_title'));
                  return;
                }
                final xp = urgency == 'مستعجل' ? 30 : (urgency == 'متوسط' ? 20 : (urgency == 'سهل' ? 10 : 5));
                s.updateTask(id,
                    title: ctl.text, project: project, xp: xp, d: date,
                    goalId: gid, clearGoal: gid == null);
                task['urgency'] = urgency;
                Navigator.pop(dctx);
              },
              child: Txt(s.t('save'), bold: true, color: Colors.white),
            ),
          ],
        );
      }),
    ),
  );
}