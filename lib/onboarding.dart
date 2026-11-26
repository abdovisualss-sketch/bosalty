import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'focus.dart';
import 'history_goals.dart';
import 'main.dart' show tabIcon, tabLabel;
import 'sounds.dart';
import 'state.dart';
import 'ui.dart';
import 'worship_log.dart';

/// First-run walkthrough for new users: a few short pages explaining how Bosalty works,
/// with a "Skip" button on every page.
///
///  * [Onboarding.maybeShow] opens it automatically the first time the app runs on a device
///    (people who already have tasks / sessions / goals are never interrupted).
///  * [Onboarding.show] opens it on demand (the Help icon (?) at the top of the screen).
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

  /// Opens the tour (also used by the Help icon (?) in the header).
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
  const _Step(this.visual, this.title, this.body, [this.tips = const [], this.numbered = true, this.story = '']);
  final Widget visual;
  final String title, body;
  /// One line of the running story (a project -> a goal -> a task -> a session), shown in a bubble under the title.
  final String story;
  final List<String> tips;
  /// true: each tip starts with a star, like the stars drawn on the picture. false: a check mark.
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
    final proj = s.pdisp(s.projectKeys.first); // the story uses the user's own first project
    return [
      _Step(
        _welcomePicture(s, p),
        l('أهلاً بك في Bosalty', 'Welcome to Bosalty'),
        l('مشاريع وأهداف ومهام ومؤقت تركيز، ومعها القرآن والأذكار.',
            'Projects, goals, tasks and a focus timer, plus Quran and adhkar.'),
        [
          l('زر (؟) أعلى الشاشة يفتح هذه الجولة من جديد.',
              'The (?) button at the top opens this tour again.'),
        ],
        false,
        l('تخيّل أن لديك مشروعًا تريد إنجازه هذا الشهر.',
            'Imagine you have a project to finish this month.'),
      ),
      _Step(
        _projectsPicture(s, p, l),
        l('أولًا: المشاريع', 'First: projects'),
        l('كل هدف ومهمة وجلسة تنتمي إلى مشروع.',
            'Every goal, task and session belongs to a project.'),
        [
          l('عدّله من الإعدادات ← تصنيف المشاريع.',
              'Edit it in Settings → Project categories.'),
          l('أضف مشروعًا جديدًا.',
              'Add a new project.'),
        ],
        true,
        l('تبدأ الحكاية بمشروعك: «$proj».',
            'The story starts with your project: “$proj”.'),
      ),
      _Step(
        _goalPicture(s, p, l),
        l('ثانيًا: أهداف الشهر', 'Second: monthly goals'),
        l('اكتب هدف الشهر واختر مشروعه.',
            'Write the month’s goal and pick its project.'),
        [
          l('علّم الدائرة عند الإنجاز.',
              'Tick the circle when done.'),
          l('«تقرير الشهر» يلخّص إنجازك.',
              'Monthly Report sums up your month.'),
        ],
        true,
        l('قررت أن هدفك هذا الشهر في «$proj»: تسليم أول نسخة.',
            'Your goal this month in “$proj”: deliver the first version.'),
      ),
      _Step(
        _addTaskPicture(s, p, l),
        l('ثالثًا: أضف مهامك', 'Third: add your tasks'),
        l('اكتب المهمة واختر المشروع والاستعجال.',
            'Type the task, pick the project and urgency.'),
        [
          l('الدائرة عند الإنجاز.',
              'The circle when done.'),
          l('▶ يختارها للمؤقت.',
              '▶ picks it for the timer.'),
          l('المصباح لمجمّع الأفكار.',
              'The bulb opens the Ideas collector.'),
        ],
        true,
        l('قسّمت الهدف إلى مهام صغيرة، أولها «كتابة المسودة».',
            'You split it into small tasks, the first one “Write the draft”.'),
      ),
      _Step(
        _browsePicture(s, p),
        l('تنقّل بين الأيام والمشاريع', 'Browse by day and project'),
        l('اختر اليوم والمشروع لترى مهامهما.',
            'Pick the day and project to see their tasks.'),
        [
          l('الأسهم للأيام، والكرة الأرضية لكل الأيام.',
              'Arrows move between days; the globe shows all days.'),
          l('اضغط مشروعًا لتصفية مهامه.',
              'Tap a project to filter its tasks.'),
        ],
      ),
      _Step(
        _timerPicture(s, p),
        l('رابعًا: شغّل مؤقت التركيز', 'Fourth: run the focus timer'),
        l('اختر المهمة والدقائق ثم «ابدأ».',
            'Choose the task and minutes, then Start.'),
        [
          l('«ابدأ» يتحوّل إلى «إيقاف مؤقت».',
              'Start turns into Pause.'),
          l('الحلقة تعرض الوقت المتبقي.',
              'The ring shows the time left.'),
        ],
        true,
        l('اخترت المهمة وضبطت 25 دقيقة وبدأت.',
            'You picked the task, set 25 minutes and started.'),
      ),
      _Step(
        _tonePicture(s, p, l),
        l('رنّة نهاية الجلسة', 'Session end tone'),
        l('الإعدادات ← الصلاة والتنبيهات ← رنّة نهاية الجلسة.',
            'Settings → Prayer & alerts → Session end tone.'),
        [
          l('▶ للاستماع، والاسم للاختيار.',
              '▶ to listen, the name to choose.'),
          l('أو اختر ملفًا من جهازك.',
              'Or pick a file from your device.'),
        ],
        false,
        l('اخترت رنّة هادئة تنبّهك عند انتهاء الجلسة.',
            'You chose a calm tone for the end of the session.'),
      ),
      _Step(
        _historyPicture(s, p, l),
        l('سجلّك', 'Your history'),
        l('وقتك اليوم والأسبوع والشهر، وتفلتر بالمشروع.',
            'Your time today, this week and this month, filtered by project.'),
        [
          l('أرقام الوقت.',
              'Time totals.'),
          l('كل جلسة بتفاصيلها.',
              'Each session in detail.'),
          l('الأذكار والقرآن تظهر هنا أيضًا.',
              'Adhkar and Quran show here too.'),
        ],
        true,
        l('انتهت الجلسة فسُجّلت في السجل.',
            'The session ends and is saved in History.'),
      ),
      _Step(
        _radioPicture(s, p, l),
        l('إذاعة القرآن', 'Quran radio'),
        l('إذاعات القرآن الكريم مباشرة.',
            'Live Quran radio stations.'),
        [
          l('اضغط البانر للاستماع فورًا.',
              'Tap the banner to listen at once.'),
          l('اختر مقرئًا أو إذاعة، والقلب للمفضلة.',
              'Pick a reciter or station; the heart saves favorites.'),
        ],
      ),
      _Step(
        _adhkarPicture(s, p, l),
        l('الأذكار', 'Adhkar'),
        l('أذكارك اليومية بعدّاد.',
            'Your daily adhkar with a counter.'),
        [
          l('الصباح والمساء والمفضلة.',
              'Morning, evening and favorites.'),
          l('أضف ذكرك الخاص.',
              'Add your own dhikr.'),
          l('القلب للمفضلة.',
              'The heart saves a favorite.'),
          l('اضغط الدائرة للعدّ.',
              'Tap the circle to count.'),
        ],
      ),
      _Step(
        _mushafPicture(s, p, l),
        l('المصحف', 'Quran text'),
        l('اقرأ بملء الشاشة واسحب بين الصفحات.',
            'Read full screen and swipe between pages.'),
        [
          l('تابع من آخر صفحة.',
              'Continue from your last page.'),
          l('تصفّح أو ابحث أو احفظ علامة.',
              'Browse, search or bookmark.'),
          l('قراءة اليوم تُسجَّل في السجل.',
              'Today’s reading is saved in History.'),
        ],
      ),
      _Step(
        _prayerPicture(s, p),
        l('التبويبات والصلاة', 'Tabs and prayer'),
        l('التبويبات بالأسفل، والصلاة القادمة بالأعلى.',
            'Tabs at the bottom, the next prayer at the top.'),
        [
          l('ستة تبويبات.',
              'Six tabs.'),
          l('الصلاة القادمة والوقت المتبقي.',
              'The next prayer and time left.'),
        ],
      ),
      _Step(
        _settingsPicture(s, p, l),
        l('الإعدادات والحساب', 'Settings and account'),
        l('أيقونة الترس أعلى الشاشة.',
            'The gear icon at the top.'),
        [
          l('تصنيف المشاريع: الاسم والصورة.',
              'Project categories: name and picture.'),
          l('تخصيص دقيق: الخطوط والتخطيط.',
              'Fine tuning: text and layout.'),
          l('النسخ الاحتياطي: احفظ واسترجع.',
              'Backup: save and restore.'),
          l('حسابي: الاسم والمزامنة وتسجيل الخروج.',
              'My account: name, sync and sign out.'),
        ],
        true,
        l('وإن أردت تغيير شيء في الحكاية فمن هنا.',
            'Want to change anything in the story? Start here.'),
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
              if (st.story.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.accent.withOpacity(0.25)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.auto_stories_rounded, size: 20, color: p.accent),
                    const SizedBox(width: 10),
                    Expanded(child: Txt(st.story, size: 14, bold: true, color: p.accent)),
                  ]),
                ),
              ],
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
                                  ? const _StarPin()
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
                      Icon(Icons.help_outline_rounded, size: 18, color: p.muted),
                      const SizedBox(width: 6),
                      Txt(s.rtl ? 'المساعدة' : 'Help', size: 13, bold: true, color: p.muted),
                      const SizedBox(width: 10),
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
// user's colours, language and project names / pictures. The stars on a picture are repeated in the tips list under it.

typedef _L = String Function(String ar, String en);

/// The marker drawn on a picture and repeated before its tip in the list: a star, never a number,
/// so it cannot be mixed up with the page numbers.
class _StarPin extends StatelessWidget {
  const _StarPin();
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pal;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.card, width: 2)),
      child: const Icon(Icons.star_rounded, size: 14, color: Colors.white),
    );
  }
}

/// Puts the star badge on the top corner of [child]. Also handed to the real widgets (as their `pin:`)
/// so they can mark their own buttons.
Widget _pin(int n, Widget child) => Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        const PositionedDirectional(top: -8, end: -8, child: _StarPin()),
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

// ---- 1b. projects: the first projects of the user (picture + name) and the "Add project" row ----
Widget _projectsPicture(AppState s, Pal p, _L l) {
  const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 2);

  Widget card(List<Widget> items) => Material(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 64, color: p.muted.withOpacity(0.12)),
            items[i],
          ],
        ]),
      );

  return _Screen(children: [
    _pin(
      1,
      card([
        for (final k in s.projectKeys.take(4))
          ListTile(
            contentPadding: pad,
            leading: SizedBox(width: 36, height: 36, child: Center(child: ProjectAvatar(k, size: 32, letter: true))),
            title: Txt(s.pdisp(k), size: 14, bold: true, color: p.proj(k)),
            subtitle: s.psub(k).isEmpty ? null : Txt(s.psub(k), size: 12, color: p.muted),
            trailing: Icon(Icons.edit_rounded, size: 18, color: p.muted),
          ),
      ]),
    ),
    const SizedBox(height: 14),
    _pin(
      2,
      card([
        ListTile(
          contentPadding: pad,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.add_rounded, size: 20, color: p.accent),
          ),
          title: Txt(l('إضافة تصنيف', 'Add project'), size: 14, bold: true, color: p.accent),
        ),
      ]),
    ),
  ]);
}

// ---- 2. add a task: the Tasks title + light bulb, the add-task card and a real task card ----
Widget _addTaskPicture(AppState s, Pal p, _L l) {
  final k = s.projectKeys.first;
  final demo = <String, dynamic>{
    'id': '_tour_task',
    'title': l('كتابة المسودة', 'Write the draft'),
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

// ---- 3b. end-of-session tone: the first rows of the real tone list + the "choose a file" row ----
Widget _tonePicture(AppState s, Pal p, _L l) {
  const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 2);
  final rows = TimerSounds.all.take(3).toList(); // the built-in tones come first

  Widget card(List<Widget> items) => Material(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: p.muted.withOpacity(0.12)),
            items[i],
          ],
        ]),
      );

  return _Screen(children: [
    card([
      for (var i = 0; i < rows.length; i++)
        ListTile(
          contentPadding: pad,
          leading: Icon(
            i == 0 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: i == 0 ? p.accent : p.muted,
          ),
          title: Txt(l(rows[i].ar, rows[i].en), size: 14, bold: i == 0, color: i == 0 ? p.accent : null),
          trailing: Icon(Icons.play_circle_fill_rounded, color: p.accent, size: 30),
        ),
    ]),
    const SizedBox(height: 14),
    card([
      ListTile(
        contentPadding: pad,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: p.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.library_music_rounded, size: 20, color: p.accent),
        ),
        title: Txt(l('اختار ملف من عندك', 'Choose a file from your device'), size: 14, bold: true, color: p.accent),
        subtitle: Txt('mp3 · wav · ogg · m4a · aac · flac', size: 12, color: p.muted),
      ),
    ]),
  ]);
}

// ---- 4. monthly goal: a real goal card and the Monthly report button ----
Widget _goalPicture(AppState s, Pal p, _L l) {
  final k = s.projectKeys.first;
  final demo = <String, dynamic>{
    'id': '_tour_goal',
    'title': l('تسليم أول نسخة', 'Deliver the first version'),
    'category': k,
    'progress': 0,
    'target': 1,
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
        task: l('كتابة المسودة', 'Write the draft'),
        minutes: 25,
      ),
    ),
    _pin(
      3,
      Column(children: [
        WorshipRow(
          at: DateTime(now.year, now.month, now.day, 6, 15),
          icon: WorshipLog.adhkarIcon('morning'),
          color: WorshipLog.adhkarColor('morning'),
          title: WorshipLog.adhkarTitle(s, 'morning'),
          detail: l('أتممتها كاملة · ١٥ ذكر', 'Completed · 15 adhkar'),
          value: '✓',
        ),
        WorshipRow(
          at: DateTime(now.year, now.month, now.day, 5, 40),
          icon: Icons.auto_stories_rounded,
          color: p.accent,
          title: l('قراءة القرآن', 'Quran reading'),
          detail: l('البقرة · ٤٥ آية', 'Al-Baqarah · 45 verses'),
          value: l('٣ صفحات', '3 pages'),
        ),
      ]),
    ),
  ]);
}

// ---- 6. the bottom bar (Focus selected) and the real prayer-times bar ----
Widget _prayerPicture(AppState s, Pal p) => _Screen(children: [
      _pin(1, _bottomBar(s, p, 0)),
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

  // a closed row of the "More" group; [pin] is the number badge shown at its end
  Widget closedRow(IconData icon, String title, {String? subtitle, int? pin}) => ListTile(
        contentPadding: pad,
        leading: badge(icon),
        title: Txt(title, size: 14),
        subtitle: subtitle == null ? null : Txt(subtitle, size: 12, color: p.muted),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (pin != null) ...[const _StarPin(), const SizedBox(width: 8)],
          Icon(Icons.expand_more_rounded, color: p.muted),
        ]),
      );

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
    group(l('المزيد', 'More'), [
      closedRow(Icons.text_fields_rounded, l('حجم الخط والقراءة', 'Text & reading size')),
      closedRow(Icons.folder_rounded, l('تصنيف المشاريع', 'Project categories'),
          subtitle: sub.isEmpty ? s.pdisp(k) : '${s.pdisp(k)} · $sub', pin: 1),
      closedRow(Icons.tune_rounded, l('تخصيص دقيق', 'Fine tuning'),
          subtitle: l('أحجام الخطوط وتخطيط شاشة التركيز', 'Text sizes and focus-screen layout'), pin: 2),
      closedRow(Icons.save_alt_rounded, l('النسخ الاحتياطي', 'Backup'),
          subtitle: l('احفظ بياناتك أو استرجعها', 'Save or restore your data'), pin: 3),
      closedRow(Icons.person_rounded, l('حسابي والملف الشخصي', 'My account & profile'), pin: 4),
    ]),
  ]);
}

// ---- 2b. browse: the real day bar and the real project filter ----
Widget _browsePicture(AppState s, Pal p) => _Screen(children: [
      _pin(1, const DayBar()),
      const SizedBox(height: 10),
      _pin(2, const ProjectFilter()),
    ]);

// ---- 8. Quran radio: the Cairo banner and the category squares (drawn like the real Radio tab) ----
Widget _radioPicture(AppState s, Pal p, _L l) {
  Widget square(IconData icon, String label, String count) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.sel, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
            child: Icon(icon, color: p.accent, size: 24),
          ),
          const SizedBox(height: 8),
          Txt(label, size: 14, bold: true, align: TextAlign.center, maxLines: 2),
          const SizedBox(height: 2),
          Txt(count, size: 12, color: p.muted, align: TextAlign.center, maxLines: 1),
        ]),
      );

  final banner = Container(
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
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Txt(l('إذاعة القرآن الكريم من القاهرة', 'Quran Radio from Cairo'),
              size: 15, bold: true, color: Colors.white, maxLines: 2),
          Txt(l('إذاعة مصر • بث مباشر', 'Egypt • Live'), size: 12, color: Colors.white70, maxLines: 1),
        ]),
      ),
      const Icon(Icons.radio_rounded, color: Colors.white, size: 24),
    ]),
  );

  return _Screen(children: [
    _pin(1, banner),
    const SizedBox(height: 14),
    _pin(2, Column(children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: square(Icons.record_voice_over_rounded, l('المقرئين', 'Reciters'), l('إذاعة', 'stations'))),
      const SizedBox(width: 12),
      Expanded(child: square(Icons.verified_rounded, l('الإذاعات الأصلية', 'Official radios'), l('إذاعة', 'stations'))),
    ]),
    const SizedBox(height: 12),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: square(Icons.favorite_rounded, l('المفضلة', 'Favorites'), l('إذاعة', 'stations'))),
      const SizedBox(width: 12),
      Expanded(child: square(Icons.radio_rounded, l('كل الإذاعات', 'All stations'), l('إذاعة', 'stations'))),
    ]),
    ])),
  ]);
}

// ---- 9. adhkar: the three buttons, the header with its progress ring, and one dhikr card ----
Widget _adhkarPicture(AppState s, Pal p, _L l) {
  const heroColors = [Color(0xFFD97706), Color(0xFFEA580C)];
  final accent = p.dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

  Widget tab(IconData icon, String label, bool on, Color c) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(color: on ? c : p.card, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: on ? Colors.white : p.muted),
            const SizedBox(width: 6),
            Flexible(child: Txt(label, size: 13, bold: true, color: on ? Colors.white : p.muted, maxLines: 1)),
          ]),
        ),
      );

  Widget miniBtn(IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
        child: Icon(icon, color: p.muted, size: 22),
      );

  final tabs = Row(children: [
    tab(Icons.wb_sunny_rounded, l('الصباح', 'Morning'), true, heroColors[0]),
    tab(Icons.nightlight_round, l('المساء', 'Evening'), false, const Color(0xFF4338CA)),
    tab(Icons.favorite_rounded, l('المفضلة', 'Favorites'), false, const Color(0xFFBE123C)),
  ]);

  final addBtn = Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.add_rounded, size: 18, color: heroColors[0]),
      const SizedBox(width: 4),
      Txt(l('إضافة ذكر', 'Add dhikr'), size: 13, bold: true, color: heroColors[0]),
    ]),
  );

  final hero = Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: heroColors),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Txt(WorshipLog.adhkarTitle(s, 'morning'),
                  size: 21, bold: true, head: true, color: Colors.white, maxLines: 1),
            ),
          ]),
          const SizedBox(height: 12),
          _pin(2, addBtn),
        ]),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 78,
        height: 78,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 0.4,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.25),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Txt('2', size: 21, bold: true, head: true, color: Colors.white),
            Txt('/ 5', size: 11, color: Colors.white.withOpacity(0.85)),
          ]),
        ]),
      ),
    ]),
  );

  final counter = SizedBox(
    width: 98,
    height: 98,
    child: Stack(alignment: Alignment.center, children: [
      SizedBox.expand(
        child: CircularProgressIndicator(
          value: 0.37,
          strokeWidth: 6,
          strokeCap: StrokeCap.round,
          color: accent,
          backgroundColor: accent.withOpacity(0.15),
        ),
      ),
      Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(p.dark ? 0.2 : 0.12)),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Txt('37', size: 26, bold: true, head: true),
            Txt('/ 100', size: 11, color: p.muted),
          ]),
        ),
      ),
    ]),
  );

  final card = Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: accent.withOpacity(p.dark ? 0.25 : 0.2), width: 1.5),
    ),
    child: Column(children: [
      Row(children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Txt(l('100 مرة', '100 times'), size: 12, bold: true, color: accent),
            ),
          ),
        ),
        _pin(3, const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22))),
      ]),
      const SizedBox(height: 6),
      Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: s.fs(19), height: 2.0, color: p.text),
        ),
      ),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        miniBtn(Icons.restart_alt_rounded),
        const SizedBox(width: 22),
        _pin(4, counter),
        const SizedBox(width: 22),
        miniBtn(Icons.done_all_rounded),
      ]),
      const SizedBox(height: 8),
      Txt(l('اضغط للعدّ', 'Tap to count'), size: 12, color: p.muted),
    ]),
  );

  return _Screen(children: [
    _pin(1, tabs),
    const SizedBox(height: 14),
    hero,
    const SizedBox(height: 14),
    card,
  ]);
}

// ---- 10. Quran text: "Continue reading", the index tabs and today's reading bar ----
Widget _mushafPicture(AppState s, Pal p, _L l) {
  final labels = [
    l('السور', 'Surahs'),
    l('الأجزاء', 'Juz'),
    l('الأحزاب', 'Hizb'),
    l('الصفحات', 'Pages'),
    l('العلامات', 'Bookmarks'),
    l('بحث', 'Search'),
  ];

  final cont = Box(
    color: p.sel,
    child: Row(children: [
      Icon(Icons.menu_book_rounded, color: p.accent),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Txt(l('متابعة القراءة', 'Continue reading'), size: 12, color: p.muted),
          Txt(l('سورة البقرة · صفحة ٥٠', 'Surah Al-Baqarah · page 50'), size: 15, bold: true),
        ]),
      ),
      Icon(s.rtl ? Icons.chevron_left : Icons.chevron_right, color: p.accent),
    ]),
  );

  final tabs = SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      for (var i = 0; i < labels.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: i == 0 ? p.accent : Colors.transparent, width: 2.5)),
          ),
          child: Txt(labels[i], size: 14, bold: i == 0, color: i == 0 ? p.accent : p.muted, maxLines: 1),
        ),
    ]),
  );

  final today = Box(
    radius: 16,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      Icon(Icons.auto_stories_rounded, color: p.accent, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Txt(l('اليوم: ٣ صفحات · ٤٥ آية', 'Today: 3 pages · 45 verses'), size: 13, bold: true, maxLines: 1),
          const SizedBox(height: 2),
          Txt(l('البقرة ص ٥٠–٥٢', 'Al-Baqarah p. 50–52'), size: 11, color: p.muted, maxLines: 1),
        ]),
      ),
      Icon(Icons.keyboard_arrow_up_rounded, color: p.muted),
    ]),
  );

  return _Screen(children: [
    _pin(1, cont),
    const SizedBox(height: 10),
    _pin(2, tabs),
    const SizedBox(height: 14),
    _pin(3, today),
  ]);
}
