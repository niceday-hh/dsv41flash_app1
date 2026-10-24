import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/budget_page.dart';
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

  Widget _addButton(Palette p) {
    return Center(
      child: Pressable(
        onTap: _add,
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
