import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/budget_page.dart';
import 'pages/calendar_page.dart';
import 'pages/insight_page.dart';
import 'ui/add_sheet.dart';
import 'voice/asr_engine.dart' as asr;
import 'voice/voice_parser.dart';
import 'voice/voice_sheet.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'theme.dart';
import 'ui/add_sheet.dart';
import 'ui/common.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    _fade.forward(from: 0);
  }

  Future<void> _add() async {
    HapticFeedback.mediumImpact();
    final bool? ok = await showAddBillSheet(context);
    if (ok == true && mounted) showToast(context, '记账成功');
  }

  Future<void> _voice() async {
    if (!asr.AsrEngine.supported) {
      showToast(context, '语音记账目前仅支持 Android 客户端', icon: Icons.mic_off_rounded);
      return;
    }
    final VoiceIntent? intent = await showVoiceSheet(context);
    if (intent == null || !mounted) return;
    final bool? ok = await showBillSheet(
      context,
      expense: intent.expense,
      catId: intent.catId,
      initialAmount: intent.amount,
      initialNote: intent.note,
    );
    if (ok == true && mounted) showToast(context, '记账成功');
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: <Widget>[
            _Backdrop(p: p),
            FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.014),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic)),
                child: IndexedStack(
                  index: _index,
                  children: const <Widget>[
                    HomePage(),
                    StatsPage(),
                    BudgetPage(),
                    SettingsPage(),
                  ],
                ),
              ),
            ),
            // 底部渐隐：让列表在导航栏下方自然淡出，避免半截内容露出
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 116,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[p.bg.withOpacity(0), p.bg.withOpacity(0.92), p.bg],
                      stops: const <double>[0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 10),
                child: _navBar(p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBar(Palette p) {
    return GlassPanel(
      radius: 28,
      opacity: 0.99,
      blur: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: <Widget>[
          _navItem(p, 0, Icons.receipt_long_rounded, Icons.receipt_long_outlined, '明细'),
          _navItem(p, 1, Icons.donut_large_rounded, Icons.donut_large_outlined, '图表'),
          Expanded(child: _addButton(p)),
          _navItem(p, 2, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, '预算'),
          _navItem(p, 3, Icons.person_rounded, Icons.person_outline_rounded, '我的'),
        ],
      ),
    );
  }

  Widget _navItem(Palette p, int i, IconData active, IconData normal, String label) {
    final bool on = _index == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(i),
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedScale(
                scale: on ? 1.08 : 1,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(
                  on ? active : normal,
                  size: 21,
                  color: on ? p.accent : p.ink3,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.1,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? p.accent : p.ink3,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickMenu() async {
    final Palette p = AppScope.paletteOf(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  _quickTile(p, '记一笔', Icons.add_rounded, p.accent, () {
                    Navigator.pop(ctx);
                    _add();
                  }),
                  const SizedBox(width: 10),
                  _quickTile(p, '语音记账', Icons.mic_rounded, const Color(0xFFF4576E), () {
                    Navigator.pop(ctx);
                    _voice();
                  }),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  _quickTile(p, '消费日历', Icons.calendar_month_rounded, const Color(0xFF4DB6AC), () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(_fadeRoute(const CalendarPage()));
                  }),
                  const SizedBox(width: 10),
                  _quickTile(p, '消费洞察', Icons.auto_awesome_rounded, const Color(0xFF9B8CFF), () {
                    Navigator.pop(ctx);
                    final DateTime now = DateTime.now();
                    Navigator.of(context).push(_fadeRoute(InsightPage(
                      start: DateTime(now.year, now.month, 1),
                      end: DateTime(now.year, now.month + 1, 0),
                      periodLabel: '${now.year}年${now.month}月',
                    )));
                  }),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '长按 + 可随时呼出快捷入口',
                style: TextStyle(fontSize: 10.5, color: p.ink3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickTile(Palette p, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Route<bool> _fadeRoute(Widget page) => PageRouteBuilder<bool>(
        pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) => page,
        transitionsBuilder: (BuildContext c, Animation<double> a, Animation<double> s, Widget child) {
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      );

  Widget _addButton(Palette p) {
    return Center(
      child: Pressable(
        onTap: _add,
        onLongPress: _quickMenu,
        scale: 0.9,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: p.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: p.accentGlow,
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 27),
        ),
      ),
    );
  }
}

/// 背景光晕
class _Backdrop extends StatelessWidget {
  final Palette p;

  const _Backdrop({Key? key, required this.p}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: p.bg),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -140,
              right: -80,
              child: _blob(p.accent.withOpacity(p.dark ? 0.16 : 0.13), 300),
            ),
            Positioned(
              top: 120,
              left: -120,
              child: _blob(p.accent2.withOpacity(p.dark ? 0.10 : 0.09), 260),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[c, c.withOpacity(0)]),
      ),
    );
  }
}
