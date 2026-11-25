import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding.dart';
import 'adhkar.dart';
import 'focus.dart';
import 'history_goals.dart';
import 'login.dart';
import 'mushaf.dart';
import 'notify.dart';
import 'quran.dart';
import 'state.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. التقاط أخطاء الـ UI
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Caught Flutter UI Error: ${details.exception}");
  };

  // 2. تجنب إغلاق الـ EXE في الويندوز عند أخطاء الـ Async
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint("Caught Async/Native Error: $error");
    return true;
  };

  try {
    await Supabase.initialize(
      url: 'https://dxhjpqiranhusctrimoa.supabase.co',
      anonKey: 'sb_publishable__k6mccu_h14oqIphOC6KSA_pnBTJ8nZ',
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  try {
    Notify.init();
  } catch (e) {
    debugPrint("Notify init error: $e");
  }

  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.bosalty.radio',
        androidNotificationChannelName: 'Quran radio',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint("JustAudioBackground error: $e");
    }
  }

  try {
    quranRadio.init();
  } catch (e) {
    debugPrint("QuranRadio init error: $e");
  }

  await OfflineMode.load();

  final state = AppState();
  try {
    await state.load();
  } catch (e) {
    debugPrint("State load error: $e");
  }

  runApp(AppScope(state: state, child: const BosaltyApp()));
}

class BosaltyApp extends StatelessWidget {
  const BosaltyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;

    return MaterialApp(
      title: 'Bosalty',
      debugShowCheckedModeBanner: false,
      locale: s.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'IBMPlexSansArabic',
        colorScheme: ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: p.bg,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'IBMPlexSansArabic',
        colorScheme: ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: p.bg,
      ),
      
      // 🛡️ تعطيل شجرة الـ Semantics بالكامل على الويندوز لمنع crash الـ accessibility_bridge.cc
      builder: (context, child) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          return ExcludeSemantics(child: child ?? const SizedBox());
        }
        return child ?? const SizedBox();
      },

      home: const AuthGate(child: Shell()),
    );
  }
}

Widget tabIcon(String name, Color c) {
  if (name == 'radio') return Icon(Icons.radio_rounded, color: c, size: 24);
  if (name == 'adhkar') return Icon(Icons.wb_twilight_rounded, color: c, size: 24);
  if (name == 'mushaf') return Icon(Icons.menu_book_rounded, color: c, size: 24);
  return Ic(name, color: c, size: 24);
}

String tabLabel(AppState s, String key) =>
    key == 'tab_adhkar'
        ? (s.rtl ? 'الأذكار' : 'Adhkar')
        : key == 'tab_mushaf'
            ? (s.rtl ? 'المصحف' : 'Quran text')
            : s.t(key);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  AppState? _s;
  int _seen = 0;
  Timer? _clock;
  String _alerted = '';

@override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => _tickPrayer());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tickPrayer();
      if (mounted) {
        final s = AppScope.of(context);
        Onboarding.maybeShow(context, s);
      }
    });
  }

  /// Keeps the phone's prayer notifications scheduled and, where the system can't notify us
  /// (Windows / web), shows the "get up and pray" reminder inside the app at each prayer time.
  void _tickPrayer() {
    final s = _s;
    if (s == null || !mounted) return;
    s.syncPrayerAlerts();
    if (Notify.supported || s.settings['prayer_alerts'] != true) return;
    final now = DateTime.now();
    final times = prayerTimes(dateOnly(now));
    for (final k in prayers) {
      final mins = (times[k]! * 60).round();
      final at = DateTime(now.year, now.month, now.day, mins ~/ 60, mins % 60);
      final late = now.difference(at);
      final key = '${iso(now)}:$k';
      if (!late.isNegative && late < const Duration(minutes: 3) && _alerted != key) {
        _alerted = key;
        _showPrayerDialog(s, k);
        break;
      }
    }
  }

  void _showPrayerDialog(AppState s, String k) {
    final p = s.pal;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        icon: Icon(Icons.notifications_active_rounded, color: p.accent, size: 34),
        title: Txt(s.t('pray_title', {'p': s.t(k)}), size: 18, bold: true, head: true, color: p.accent, align: TextAlign.center),
        content: Txt(s.t('pray_body'), size: 15, align: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: () => Navigator.pop(ctx),
            child: Txt(s.t('pray_ok'), bold: true, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    if (!identical(_s, s)) {
      _s?.removeListener(_onChange);
      _s = s;
      _seen = s.toastSeq;
      s.addListener(_onChange);
    }
  }

  void _onChange() {
    final s = _s!;
    s.syncPrayerAlerts();
    if (s.toastSeq == _seen) return;
    _seen = s.toastSeq;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        content: Text(s.toastMsg),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ));
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _s?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.pal;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    const tabs = [
      ['home', 'tab_focus'],
      ['history', 'tab_history'],
      ['goals', 'tab_goals'],
      ['radio', 'tab_quran'],
      ['adhkar', 'tab_adhkar'],
      ['mushaf', 'tab_mushaf'],
    ];

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(children: [
          const Header(),
          if (s.settings['show_prayers'] == true && s.tab != 5) const PrayerBanner(), // tab 5 = Mushaf: full-screen reading
          Expanded(
            child: IndexedStack(index: s.tab, children: const [
              FocusScreen(),
              Constrained(child: HistoryScreen()),
              Constrained(child: GoalsScreen()),
              Constrained(child: QuranScreen()),
              Constrained(child: AdhkarScreen()),
              Constrained(child: MushafScreen()),
            ]),
          ),
        ]),
      ),
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: wide
            ? Row(children: [
                NavigationRail(
                  backgroundColor: p.card,
                  indicatorColor: p.sel,
                  selectedIndex: s.tab,
                  onDestinationSelected: s.setTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final t in tabs)
                      NavigationRailDestination(
                        icon: tabIcon(t[0], p.muted),
                        selectedIcon: tabIcon(t[0], p.accent),
                        label: Txt(tabLabel(s, t[1]), size: 12),
                      ),
                  ],
                ),
                Expanded(child: content),
              ])
            : content,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: p.card,
              indicatorColor: p.sel,
              selectedIndex: s.tab,
              onDestinationSelected: s.setTab,
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: tabIcon(t[0], p.muted),
                    selectedIcon: tabIcon(t[0], p.accent),
                    label: tabLabel(s, t[1]),
                  ),
              ],
            ),
    );
  }
}

