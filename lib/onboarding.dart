import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';
import 'ui.dart';

/// First-run walkthrough for new users: a few short pages explaining how Bosalty works,
/// with a "Skip" button on every page.
///
///  * [Onboarding.maybeShow] opens it automatically the first time the app runs on a device
///    (people who already have tasks / sessions / goals are never interrupted).
///  * [Onboarding.show] opens it on demand (the "App tour" row in Settings).
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
  const _Step(this.visual, this.title, this.body, [this.tips = const []]);
  final Widget visual;
  final String title, body;
  final List<String> tips;
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

  Widget _ring(Pal p, Widget icon) => Container(
        width: 112,
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
        child: icon,
      );

  List<_Step> _steps(AppState s, Pal p) {
    String l(String ar, String en) => s.rtl ? ar : en;
    return [
      _Step(
        AccentImage('assets/brand/seal.png', width: 120, height: 120),
        l('أهلاً بك في Bosalty', 'Welcome to Bosalty'),
        l('مكان واحد لتنظيم يومك: مهامك، مؤقت تركيز، أهداف الشهر، وكمان القرآن والأذكار ومواقيت الصلاة. جولة سريعة من دقيقة وتكون جاهز.',
            'One place to organise your day: tasks, a focus timer, monthly goals, plus Quran, adhkar and prayer times. A one-minute tour and you are ready.'),
        [l('تقدر تتخطى الجولة في أي وقت، وتعيدها من الإعدادات.', 'You can skip the tour any time and replay it from Settings.')],
      ),
      _Step(
        _ring(p, Ic('tasks', color: p.accent, size: 48)),
        l('ابدأ بإضافة مهمة', 'Start by adding a task'),
        l('في تبويب «التركيز» اكتب اسم المهمة، اختر المشروع ومستوى الاستعجال، وإن كان لها هدف شهري اربطها به، ثم اضغط «إضافة».',
            'In the Focus tab type the task name, pick the project and the urgency level, link it to a monthly goal if it has one, then press Add.'),
        [
          l('الدائرة بجانب المهمة: اضغطها عند الإنجاز لتحصل على نقاط.', 'The circle next to a task: tap it when you finish to earn points.'),
          l('زر التشغيل ▶: يختار المهمة للمؤقت لتسجّل وقتك عليها.', 'The play button ▶ picks the task for the timer, so your time is logged on it.'),
          l('أيقونة المصباح تفتح «مجمّع الأفكار» للمهام من نوع «فكرة».', 'The light-bulb icon opens the Ideas collector for tasks marked as ideas.'),
        ],
      ),
      _Step(
        _ring(p, Ic('timer', color: p.accent, size: 48)),
        l('شغّل مؤقت التركيز', 'Run the focus timer'),
        l('في أعلى شاشة «التركيز» اختر المشروع والمهمة، حدّد الدقائق من الأزرار السريعة، واضغط «ابدأ».',
            'At the top of the Focus tab choose the project and task, pick the minutes from the quick buttons, and press Start.'),
        [
          l('أثناء الجلسة تثبت المهمة والإعدادات حتى تنتهي أو تضغط «إعادة».', 'While a session runs the task and settings are locked until it ends or you press Reset.'),
          l('عند انتهاء الجلسة تُسجَّل في السجل وتحصل على نقاط ويصلك تنبيه.', 'When it ends it is saved to History, you earn points and get an alert.'),
        ],
      ),
      _Step(
        _ring(p, Ic('goals', color: p.accent, size: 48)),
        l('أهداف الشهر', 'Monthly goals'),
        l('من تبويب «الأهداف» اكتب هدفك واختر له مشروعًا وعدد نقاط. يزيد تقدّمه مع المهام التي تربطها به، أو يدويًا بزر +١.',
            'In the Goals tab write your goal and choose a project and a points target. It moves forward with the tasks you link to it, or manually with the +1 button.'),
        [
          l('عند اكتمال الهدف تحصل على نقاط مكافأة.', 'You get bonus points when a goal is completed.'),
          l('زر «تقرير الشهر» يلخّص إنجازك وتقدر تنسخه.', 'The Monthly Report button summarises your month and lets you copy it.'),
        ],
      ),
      _Step(
        _ring(p, Ic('history', color: p.accent, size: 48)),
        l('سجلّك ونقاطك', 'Your history and points'),
        l('كل جلسة تركيز تنتهي تظهر في تبويب «السجل» مع إحصائيات اليوم والأسبوع والشهر، وتقدر تفلتر بالمشروع.',
            'Every finished focus session appears in the History tab with today, week and month totals, and you can filter by project.'),
        [
          l('كل مهمة وكل جلسة تعطيك نقاط XP، وكل 100 نقطة = مستوى جديد.', 'Every task and session gives you XP, and every 100 XP is a new level.'),
          l('تفتح شارات وتحافظ على تتابع أيام الإنجاز.', 'You unlock badges and keep a streak of active days.'),
        ],
      ),
      _Step(
        _ring(p, Icon(Icons.menu_book_rounded, color: p.accent, size: 48)),
        l('القرآن والأذكار والصلاة', 'Quran, adhkar and prayer'),
        l('«إذاعة» للبث المباشر للقرآن، «الأذكار» لأذكار الصباح والمساء، و«المصحف» للقراءة بملء الشاشة.',
            'Radio for live Quran broadcasts, Adhkar for morning and evening remembrances, and Quran text for full-screen reading.'),
        [
          l('شريط مواقيت الصلاة (بتوقيت القاهرة) يظهر أعلى الشاشة.', 'The prayer-times bar (Cairo time) sits at the top of the screen.'),
          l('يصلك تذكير عند كل صلاة، وتقدر توقفه من الإعدادات.', 'You get a reminder at each prayer, and you can turn it off in Settings.'),
        ],
      ),
      _Step(
        _ring(p, Icon(Icons.tune_rounded, color: p.accent, size: 48)),
        l('الإعدادات والحساب', 'Settings and account'),
        l('أيقونة الإعدادات أعلى الشاشة تفتح: الوضع الداكن، اللغة، لون التطبيق، حجم الخط، والنسخ الاحتياطي.',
            'The settings icon at the top opens dark mode, language, accent colour, text size and backups.'),
        [
          l('لو سجّلت دخولك، بياناتك تتزامن بين أجهزتك.', 'If you are signed in, your data syncs between your devices.'),
          l('احفظ نسخة احتياطية من وقت لآخر.', 'Save a backup from time to time.'),
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
              const SizedBox(height: 28),
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
                      for (final t in st.tips)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(Icons.check_circle_rounded, size: 18, color: p.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Txt(t, size: 14)),
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
