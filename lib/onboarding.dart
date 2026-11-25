import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'focus.dart';
import 'history_goals.dart';
import 'main.dart' show tabIcon, tabLabel;
import 'state.dart';
import 'ui.dart';

/// First-run walkthrough for new users: a few short pages explaining how Bosalty works,
/// with a "Skip" button on every page.
///
///  * [Onboarding.maybeShow] opens it automatically the first time the app runs on a device
///    (people who already have tasks / sessions / goals are never interrupted).
///  * [Onboarding.show] opens it on demand (the "App tour" row in Settings).
///
/// The pictures are the app's OWN widgets (task card, timer, goal card, history rows, prayer bar, bottom bar),
/// drawn with example data and not tappable, so the tour always looks exactly like the real screens.
///
/// The "already seen" flag lives in SharedPreferences, outside the synced app data,
/// so it is per device and never ends up in backups.
class Onboarding {
  static const _key = 'bosalty_tour_seen';

  static Future<bool> _seen() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, true);
    } catch (_) {}
  }

  /// Shows the tour once. Call it after the first frame of the main screen.
  static Future<void> maybeShow(BuildContext context, AppState s) async {
    if (await _seen()) return;
    if (s.tasks.isNotEmpty || s.sessions.isNotEmpty || s.goals.isNotEmpty) {
      await markSeen(); // an existing user: no need for a tour
      return;
    }
    if (!context.mounted) return;
    await show(context);
  }

  /// Opens the tour (also used by the replay button in Settings).
  /// Whatever way it is closed (Skip, Start, Esc, Android back) it is marked as seen.
  static Future<void> show(BuildContext context) {
    final s = AppScope.of(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'tour',
      barrierColor: s.pal.bg,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => AppScope(state: s, child: const _TourPage()),
      transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ).whenComplete(markSeen);
  }
}

class _Step {
  const _Step(this.visual, this.title, this.body, [this.tips = const [], this.numbered = true]);
  final Widget visual;
  final String title, body;
  final List<String> tips;
  /// true: the tips are numbered 1, 2, 3 like the markers drawn on the picture.
  final bool numbered;
}

class _TourPage extends StatefulWidget {
  const _TourPage();
  @override
  State<_TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<_TourPage> {
  final _ctl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _go(int to, int count) {
    if (to < 0 || to >= count) return;
    _ctl.animateToPage(to, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _close() => Navigator.of(context).pop();

  List<_Step> _steps(AppState s, Pal p) {
    String l(String ar, String en) => s.rtl ? ar : en;
    return [
      _Step(
        _welcomePicture(s, p),
        l('أهلاً بك في Bosalty', 'Welcome to Bosalty'),
        l('مكان واحد لتنظيم يومك: مهامك، مؤقت تركيز، أهداف الشهر، وكمان القرآن والأذكار ومواقيت الصلاة. جولة سريعة من دقيقة وتكون جاهز.',
            'One place to organise your day: tasks, a focus timer, monthly goals, plus Quran, adhkar and prayer times. A one-minute tour and you are ready.'),
        [l('تقدر تتخطى الجولة في أي وقت، وتعيدها من أيقونة الجولة أعلى الشاشة.', 'You can skip the tour any time and replay it from the tour icon at the top of the screen.')],
        false,
      ),
      _Step(
        _addTaskPicture(s, p, l),
        l('ابدأ بإضافة مهمة', 'Start by adding a task'),
        l('في تبويب «التركيز» اكتب اسم المهمة، اختر المشروع ودرجة الاستعجال، واربطها بهدف الشهر لو لها هدف، ثم اضغط «إضافة».',
            'In the Focus tab type the task name, pick the project and the urgency, link it to a monthly goal if it has one, then press Add.'),
        [
          l('الدائرة بجانب المهمة: اضغطها عند إنجازها، ولو كانت مربوطة بهدف يزيد تقدّمه تلقائيًا.',
              'The circle next to a task: tap it when you finish it. If the task is linked to a goal, the goal moves forward by itself.'),
          l('زر التشغيل ▶: يختار المهمة للمؤقت لتسجّل وقتك عليها.', 'The play button ▶ picks the task for the timer, so your time is logged on it.'),
          l('أيقونة المصباح تفتح «مجمّع الأفكار» للمهام من نوع «فكرة».', 'The light-bulb icon opens the Ideas collector for tasks marked as ideas.'),
        ],
      ),
      _Step(
        _timerPicture(s, p),
        l('شغّل مؤقت التركيز', 'Run the focus timer'),
        l('في بطاقة «مؤقت التركيز» اختر المشروع والمهمة، حدّد الدقائق من الأزرار السريعة، واضغط «ابدأ».',
            'In the Focus Timer card choose the project and task, pick the minutes from the quick buttons, and press Start.'),
        [
          l('زر «ابدأ» يشغّل المؤقت ويتحوّل إلى «إيقاف مؤقت» أثناء الجلسة، وزر «إعادة» يبدأ من جديد.',
              'Start runs the timer and turns into Pause while it runs; Reset starts over.'),
          l('الحلقة تعرض الوقت المتبقي. أثناء الجلسة تثبت المهمة والإعدادات حتى تنتهي أو تضغط «إعادة»، وعند انتهائها تُسجَّل في السجل ويصلك تنبيه.',
              'The ring shows the time left. While a session runs the task and settings are locked until it ends or you press Reset; when it ends it is saved to History and you get an alert.'),
        ],
      ),
      _Step(
        _goalPicture(s, p, l),
        l('أهداف الشهر', 'Monthly goals'),
        l('من تبويب «الأهداف» اكتب هدفك، واختر له مشروعًا وعددًا مستهدفًا. يزيد تقدّمه مع المهام التي تربطها به، أو يدويًا بزر +١.',
            'In the Goals tab write your goal and choose a project and a target number. It moves forward with the tasks you link to it, or manually with the +1 button.'),
        [
          l('زرّا +١ و −١ يغيّران التقدّم يدويًا.', 'The +1 and −1 buttons change the progress by hand.'),
          l('زر «تقرير الشهر» يلخّص إنجازك وتقدر تنسخه.', 'The Monthly Report button summarises your month and lets you copy it.'),
        ],
      ),
      _Step(
        _historyPicture(s, p, l),
        l('سجلّك', 'Your history'),
        l('كل جلسة تركيز تنتهي تظهر في تبويب «السجل» مع إجمالي اليوم والأسبوع والشهر، وتقدر تفلتر بالمشروع.',
            'Every finished focus session appears in the History tab with today, week and month totals, and you can filter by project.'),
        [
          l('الإحصائيات: وقتك اليوم وهذا الأسبوع وهذا الشهر، وعدد الجلسات.', 'The totals: your time today, this week and this month, and the number of sessions.'),
          l('كل جلسة بوقتها ومشروعها والمهمة التي اشتغلت عليها ومدّتها.', 'Each session with its time, project, the task you worked on and its length.'),
        ],
      ),
      _Step(
        _prayerPicture(s, p),
        l('القرآن والأذكار والصلاة', 'Quran, adhkar and prayer'),
        l('«إذاعة» للبث المباشر للقرآن، «الأذكار» لأذكار الصباح والمساء، و«المصحف» للقراءة بملء الشاشة.',
            'Radio for live Quran broadcasts, Adhkar for morning and evening remembrances, and Quran text for full-screen reading.'),
        [
          l('الشريط السفلي فيه تبويبات التطبيق كلها، ومنها الإذاعة والأذكار والمصحف.', 'The bottom bar holds all the app tabs, including Radio, Adhkar and Quran text.'),
          l('شريط مواقيت الصلاة (بتوقيت القاهرة) يعرض الصلاة القادمة والوقت المتبقي، ويصلك تذكير عند كل صلاة وتقدر توقفه من الإعدادات.',
              'The prayer-times bar (Cairo time) shows the next prayer and the time left, and you get a reminder at each prayer that you can turn off in Settings.'),
        ],
      ),
      _Step(
        _settingsPicture(s, p, l),
        l('الإعدادات والحساب', 'Settings and account'),
        l('أيقونة الإعدادات أعلى الشاشة تفتح: الوضع الداكن، اللغة، لون التطبيق، حجم الخط، تصنيفات المشاريع، والنسخ الاحتياطي.',
            'The settings icon at the top opens dark mode, language, accent colour, text size, project categories and backups.'),
        [
          l('تصنيفات المشاريع: عدّل اسم أي مشروع وصورته، أو أضف تصنيفًا جديدًا.', 'Project categories: edit the name and picture of any project, or add a new one.'),
          l('احفظ نسخة احتياطية من وقت لآخر. ولو سجّلت دخولك، بياناتك تتزامن بين أجهزتك.', 'Save a backup from time to time. If you are signed in, your data syncs between your devices.'),
        ],
      ),
    ];
  }

  Widget _page(AppState s, Pal p, _Step st) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight > 16 ? c.maxHeight - 16 : 0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              st.visual,
              const SizedBox(height: 24),
              Txt(st.title, size: 24, bold: true, head: true, align: TextAlign.center),
              const SizedBox(height: 12),
              Txt(st.body, size: 15, color: p.muted, align: TextAlign.center),
              if (st.tips.isNotEmpty) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: Box(
                    color: p.card,
                    child: Column(children: [
                      for (var i = 0; i < st.tips.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: st.numbered
                                  ? NumPin(i + 1)
                                  : Icon(Icons.check_circle_rounded, size: 18, color: p.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Txt(st.tips[i], size: 14)),
                          ]),
                        ),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final steps = _steps(s, p);
    final n = steps.length;
    final last = _i == n - 1;
    final next = s.rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final prev = s.rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(25));

    return CallbackShortcuts(
      bindings: {
        SingleActivator(next): () {
          if (_i >= n - 1) {
            _close();
          } else {
            _go(_i + 1, n);
          }
        },
        SingleActivator(prev): () => _go(_i - 1, n),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: p.bg,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [
                  // step counter + Skip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                    child: Row(children: [
                      Txt('${_i + 1} / $n', size: 13, bold: true, color: p.muted),
                      const Spacer(),
                      Visibility(
                        visible: !last,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TextButton(
                          onPressed: _close,
                          child: Txt(s.rtl ? 'تخطي' : 'Skip', size: 14, bold: true, color: p.muted),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _ctl,
                      itemCount: n,
                      onPageChanged: (i) => setState(() => _i = i),
                      itemBuilder: (_, i) => _page(s, p, steps[i]),
                    ),
                  ),
                  // dots
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var k = 0; k < n; k++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == _i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: k == _i ? p.accent : p.track,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ]),
                  // back / next
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Row(children: [
                      if (_i > 0) ...[
                        OutlinedButton(
                          onPressed: () => _go(_i - 1, n),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            side: BorderSide(color: p.track),
                            shape: btnShape,
                          ),
                          child: Txt(s.rtl ? 'السابق' : 'Back', size: 14, bold: true, color: p.muted),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (last) {
                              _close();
                            } else {
                              _go(_i + 1, n);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: p.accent,
                            minimumSize: const Size(0, 50),
                            shape: btnShape,
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Txt(
                              last ? (s.rtl ? 'ابدأ الآن' : "Let's start") : (s.rtl ? 'التالي' : 'Next'),
                              size: 15,
                              bold: true,
                              color: Colors.white,
                            ),
                            if (!last) ...[
                              const SizedBox(width: 8),
                              Icon(s.rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                                  size: 18, color: Colors.white),
                            ],
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ======================= pictures for the tour =======================
// These are the app's own widgets (TaskCard, TimerCard, GoalCard, StatsGrid, SessionRow, PrayerBanner, the bottom
// NavigationBar...) filled with example data and not tappable, so they are always identical to the real screens, in the
// user's colours, language and project names / pictures. The numbers on a picture are repeated in the tips list under it.

typedef _L = String Function(String ar, String en);

/// Puts the numbered badge on the top corner of [child]. Also handed to the real widgets (as their `pin:`)
/// so they can mark their own buttons.
Widget _pin(int n, Widget child) => Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(top: -8, end: -8, child: NumPin(n)),
      ],
    );

/// A picture of a real screen: phone-width, not tappable.
class _Screen extends StatelessWidget {
  const _Screen({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: IgnorePointer(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}

// the same six tabs as the real bottom bar (see Shell in main.dart)
const _tabs = [
  ['home', 'tab_focus'],
  ['history', 'tab_history'],
  ['goals', 'tab_goals'],
  ['radio', 'tab_quran'],
  ['adhkar', 'tab_adhkar'],
  ['mushaf', 'tab_mushaf'],
];

/// The real bottom navigation bar, with tab [sel] selected.
Widget _bottomBar(AppState s, Pal p, int sel) => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: NavigationBar(
        backgroundColor: p.card,
        indicatorColor: p.sel,
        selectedIndex: sel,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: tabIcon(t[0], p.muted),
              selectedIcon: tabIcon(t[0], p.accent),
              label: tabLabel(s, t[1]),
            ),
        ],
      ),
    );

// ---- 1. welcome: the logo and the bottom bar with the six tabs ----
Widget _welcomePicture(AppState s, Pal p) {
  return Column(mainAxisSize: MainAxisSize.min, children: [
    AccentImage('assets/brand/seal.png', width: 110, height: 110),
    const SizedBox(height: 16),
    _Screen(children: [_bottomBar(s, p, 0)]),
  ]);
}

// ---- 2. add a task: the Tasks title + light bulb, the add-task card and a real task card ----
Widget _addTaskPicture(AppState s, Pal p, _L l) {
  final k = s.projectKeys.first;
  final demo = <String, dynamic>{
    'id': '_tour_task',
    'title': l('مثال: مراجعة التقرير', 'Example: review the report'),
    'project': k,
    'urgency': 'متوسط',
    'done': false,
    'date': iso(s.day),
  };
  return _Screen(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Txt(s.t('tasks'), size: 18, bold: true, head: true, sec: 'tasks'),
      _pin(
        3,
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 24),
        ),
      ),
    ]),
    const SizedBox(height: 8),
    const AddTaskCard(),
    const SizedBox(height: 8),
    TaskCard(task: demo, minutes: 25, pin: _pin),
  ]);
}

// ---- 3. the focus timer: the real Timer card ----
Widget _timerPicture(AppState s, Pal p) => _Screen(children: [TimerCard(pin: _pin)]);

// ---- 4. monthly goal: a real goal card and the Monthly report button ----
Widget _goalPicture(AppState s, Pal p, _L l) {
  final k = s.projectKeys.first;
  final demo = <String, dynamic>{
    'id': '_tour_goal',
    'title': l('مثال: إنهاء 3 وحدات دراسية', 'Example: finish 3 course modules'),
    'category': k,
    'progress': 3,
    'target': 5,
  };
  return _Screen(children: [
    Row(children: [
      Expanded(child: Txt(s.t('goals_sum', {'d': 0, 'n': 1}), size: 13, sec: 'goals', color: p.muted)),
      _pin(
        2,
        TextButton.icon(
          onPressed: () {},
          icon: const Text('📊'),
          label: Txt(s.t('monthly_report'), size: 13, bold: true, sec: 'goals', color: p.accent),
        ),
      ),
    ]),
    GoalCard(goal: demo, pin: _pin),
  ]);
}

// ---- 5. history: the real totals and a real session row ----
Widget _historyPicture(AppState s, Pal p, _L l) {
  final k = s.projectKeys.first;
  final now = DateTime.now();
  return _Screen(children: [
    _pin(
      1,
      StatsGrid(stats: [
        ['today', 'sun', s.fmtMin(90)],
        ['week', 'history', s.fmtMin(420)],
        ['month', 'goals', s.fmtMin(1500)],
        ['total', 'timer', '12'],
      ]),
    ),
    Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(children: [
        Expanded(child: Txt(s.t('today'), size: 15, bold: true, sec: 'history')),
        Txt(s.fmtMin(25), size: 13, sec: 'history', color: p.muted),
      ]),
    ),
    _pin(
      2,
      SessionRow(
        at: DateTime(now.year, now.month, now.day, 10, 30),
        project: k,
        task: l('مراجعة التقرير', 'Review the report'),
        minutes: 25,
      ),
    ),
  ]);
}

// ---- 6. the bottom bar (Radio selected) and the real prayer-times bar ----
Widget _prayerPicture(AppState s, Pal p) => _Screen(children: [
      _pin(1, _bottomBar(s, p, 3)),
      const SizedBox(height: 16),
      _pin(2, const PrayerBanner()),
    ]);

// ---- 7. settings: the same groups and rows as the real Settings sheet ----
Widget _settingsPicture(AppState s, Pal p, _L l) {
  final k = s.projectKeys.first;

  Widget badge(IconData icon) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: p.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: p.accent),
      );

  Widget group(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Txt(title, size: 12, bold: true, color: p.muted),
        ),
        Material(
          color: p.card,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 64, color: p.muted.withOpacity(0.12)),
              rows[i],
            ],
          ]),
        ),
      ]);

  const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 2);
  final sub = s.psub(k);

  return _Screen(children: [
    group(l('المظهر', 'Appearance'), [
      SwitchListTile(
        contentPadding: pad,
        value: s.dark,
        activeColor: p.accent,
        secondary: badge(s.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
        title: Txt(l('الوضع الداكن', 'Dark mode'), size: 14),
        onChanged: (_) {},
      ),
      ListTile(
        contentPadding: pad,
        leading: badge(Icons.language_rounded),
        title: Txt(l('اللغة', 'Language'), size: 14),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.swap_horiz_rounded, size: 16, color: p.accent),
            const SizedBox(width: 6),
            Txt(s.lang == 'ar' ? 'العربية' : 'English', size: 12, bold: true, color: p.accent),
          ]),
        ),
      ),
    ]),
    const SizedBox(height: 20),
    _pin(
      1,
      group(l('تصنيف المشاريع', 'Project categories'), [
        ListTile(
          contentPadding: pad,
          leading: SizedBox(width: 36, height: 36, child: Center(child: ProjectAvatar(k, size: 32, letter: true))),
          title: Txt(s.pdisp(k), size: 14, bold: true, color: p.proj(k)),
          subtitle: sub.isEmpty ? null : Txt(sub, size: 12, color: p.muted),
          trailing: Icon(Icons.edit_rounded, size: 18, color: p.muted),
        ),
        ListTile(
          contentPadding: pad,
          leading: badge(Icons.add_rounded),
          title: Txt(l('إضافة تصنيف', 'Add project'), size: 14, bold: true, color: p.accent),
        ),
      ]),
    ),
    const SizedBox(height: 20),
    _pin(
      2,
      group(l('النسخ الاحتياطي', 'Backup'), [
        ListTile(
          contentPadding: pad,
          leading: badge(Icons.save_alt_rounded),
          title: Txt(l('حفظ نسخة احتياطية كملف', 'Save backup as a file'), size: 14),
          subtitle: Txt(l('ملف JSON فيه كل بياناتك، احتفظ به في مكان آمن', 'A JSON file with all your data. Keep it somewhere safe'),
              size: 12, color: p.muted),
        ),
      ]),
    ),
  ]);
}
