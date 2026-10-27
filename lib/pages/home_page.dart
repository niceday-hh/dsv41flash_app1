import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/add_sheet.dart';
import '../ui/amount_keypad.dart';
import '../ui/category_picker.dart';
import '../ui/note_picker.dart';
import '../ui/whale_mark.dart';
import 'calendar_page.dart';
import 'search_page.dart';
import '../ui/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _month;
  int _revealKey = 0;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  bool get _isCurrentMonth {
    final DateTime now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) {
    final DateTime next = DateTime(_month.year, _month.month + delta, 1);
    final DateTime now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    HapticFeedback.selectionClick();
    setState(() {
      _month = next;
      _revealKey++;
    });
  }

  /// 与上月同期对比
  double _momDelta(double current) {
    final DateTime prevMonth = DateTime(_month.year, _month.month - 1, 1);
    final int lastDayPrev = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
    final int upto = _isCurrentMonth ? DateTime.now().day.clamp(1, lastDayPrev) : lastDayPrev;
    double prev = 0;
    for (final Bill b in AppScope.storeOf(context).bills) {
      if (!b.expense) continue;
      if (b.date.year == prevMonth.year && b.date.month == prevMonth.month && b.date.day <= upto) {
        prev += b.amount;
      }
    }
    if (prev <= 0) return 0;
    return (current - prev) / prev;
  }

  String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 11) return '早上好';
    if (h < 13) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final List<Bill> monthBills = AppStore.inMonth(store.bills, _month);
    final double expense = AppStore.total(monthBills, expense: true);
    final double income = AppStore.total(monthBills, expense: false);
    final List<DayGroup> groups = AppStore.groupByDay(monthBills);
    final double delta = _momDelta(expense);

    int activeDays = <String>{}.length;
    final Set<String> days = <String>{};
    for (final Bill b in monthBills) {
      days.add('${b.date.day}');
    }
    activeDays = days.length;
    final double dailyAvg = activeDays == 0 ? 0 : expense / activeDays;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 132),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: <Widget>[
          _header(p, store),
          const SizedBox(height: 18),
          _heroCard(p, expense, income, delta, dailyAvg),
          const SizedBox(height: 14),
          _quickRow(p, store),
          const SizedBox(height: 22),
          SectionTitle(
            title: _isCurrentMonth ? '本月账单' : '${_month.month}月账单',
            action: '日历',
            onAction: () {
              Navigator.of(context).push(PageRouteBuilder<bool>(
                pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) => const CalendarPage(),
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
              ));
            },
            trailing: Row(
              children: <Widget>[
                Text(
                  '共 ${monthBills.length} 笔',
                  style: TextStyle(fontSize: 12, color: p.ink3, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          if (groups.isEmpty)
            EmptyState(
              title: '这个月还没有记账',
              desc: '点击下方 + 记录第一笔消费吧',
            )
          else
            _Reveal(
              key: ValueKey<String>('$_revealKey-month'),
              delay: 40,
              child: SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < groups.length; i++) ...<Widget>[
                      _daySection(p, store, groups[i], isFirst: i == 0),
                      if (i != groups.length - 1)
                        Divider(height: 1, thickness: 1, color: p.line, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(Palette p, AppStore store) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_greeting()}，${store.userName}',
                style: T.h1(p).copyWith(fontSize: 24),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '今天也要认真对待每一笔开销',
                style: TextStyle(fontSize: 12.5, color: p.ink2, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Pressable(
          onTap: () {
            Navigator.of(context).push(PageRouteBuilder<bool>(
              pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) => const SearchPage(),
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
            ));
          },
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: p.shadow,
            ),
            child: Icon(Icons.search_rounded, size: 20, color: p.ink2),
          ),
        ),
        Pressable(
          onTap: () {
            HapticFeedback.selectionClick();
            AppScope.storeOf(context).setHideAmounts(!AppScope.storeOf(context).hideAmounts);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppScope.storeOf(context).hideAmounts ? p.accent.withOpacity(0.12) : p.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: p.shadow,
            ),
            child: Icon(
              AppScope.storeOf(context).hideAmounts ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 19,
              color: AppScope.storeOf(context).hideAmounts ? p.accent : p.ink2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Pressable(
          onTap: () => showToast(context, '这是你的专属账本', icon: Icons.favorite_rounded),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: p.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: p.accentGlow,
            ),
            alignment: Alignment.center,
            child: const WhaleMark(size: 27, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(Palette p, double expense, double income, double delta, double dailyAvg) {
    final bool up = delta > 0;
    final double budget = AppScope.storeOf(context).monthlyBudget;
    final double budgetPct = budget <= 0 ? 0 : (expense / budget * 100).clamp(0, 999);
    final String deltaText = delta.abs() < 0.0001
        ? '与上月持平'
        : '较上月 ${up ? '↑' : '↓'} ${(delta.abs() * 100).toStringAsFixed(1)}%';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[p.accent, p.accent2, p.accent2.withOpacity(0.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: p.accentGlow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -60,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _monthSwitcher(p),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.savings_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '预算已用 ${budgetPct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isCurrentMonth ? '本月支出' : '当月支出',
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.82), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 6),
                        child: Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: AnimatedMoney(
                          value: expense,
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1.6,
                            height: 1.0,
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        deltaText,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '日均 ${AppScope.storeOf(context).money(dailyAvg)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: <Widget>[
                        _heroStat('本月收入', income, Icons.south_west_rounded),
                        Container(width: 1, height: 24, color: Colors.white.withOpacity(0.18)),
                        _heroStat('本月结余', income - expense, Icons.account_balance_wallet_rounded),
                        Container(width: 1, height: 24, color: Colors.white.withOpacity(0.18)),
                        _heroStat('记账笔数', _monthBillCount(), Icons.receipt_long_rounded, isCount: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _monthBillCount() => AppStore.inMonth(AppScope.storeOf(context).bills, _month).length;

  Widget _heroStat(String label, num value, IconData icon, {bool isCount = false}) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 10.5, color: Colors.white.withOpacity(0.75)),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isCount ? '${value.toInt()}' : AppScope.storeOf(context).money(value),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthSwitcher(Palette p) {
    return Row(
      children: <Widget>[
        GestureDetector(
          onTap: () => _shiftMonth(-1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
            child: Icon(Icons.chevron_left_rounded, size: 20, color: Colors.white.withOpacity(0.9)),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: Text(
            monthLabel(_month),
            key: ValueKey<String>(monthLabel(_month)),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        GestureDetector(
          onTap: () => _shiftMonth(1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white.withOpacity(_isCurrentMonth ? 0.28 : 0.9),
            ),
          ),
        ),
        if (!_isCurrentMonth) ...<Widget>[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              final DateTime now = DateTime.now();
              setState(() => _month = DateTime(now.year, now.month, 1));
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                '回到本月',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickRow(Palette p, AppStore store) {
    const List<String> ids = <String>['food', 'traffic', 'shop', 'fun'];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: <Widget>[
                Icon(Icons.bolt_rounded, size: 15, color: p.accent),
                const SizedBox(width: 4),
                Text('快捷记账', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
                const Spacer(),
                Text('点击快速记账', style: TextStyle(fontSize: 10.5, color: p.ink3)),
              ],
            ),
          ),
          Row(
            children: ids.map((String id) {
              final CategoryDef c = catById(id);
              final Color tone = c.color;
              return Expanded(
                child: Pressable(
                  onTap: () async {
                    final bool? ok = await showAddBillSheet(context, expense: true, catId: id);
                    if (ok == true && mounted) showToast(context, '已记入 ${c.name}');
                  },
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: tone.withOpacity(p.dark ? 0.20 : 0.13),
                          borderRadius: BorderRadius.circular(R.m),
                        ),
                        child: Icon(c.icon, size: 21, color: tone),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.ink2),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _daySection(Palette p, AppStore store, DayGroup g, {bool isFirst = false}) {
    final bool today = _isToday(g.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(14, isFirst ? 14 : 12, 16, 6),
          child: Row(
            children: <Widget>[
              _dayPill(p, g.day, today),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        dayLabel(g.day),
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${g.bills.length} 笔',
                        style: TextStyle(fontSize: 10.5, color: p.ink3, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${g.day.month} 月 ${g.day.day} 日',
                    style: TextStyle(fontSize: 10.5, color: p.ink3, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
              if (g.expense > 0)
                Text(
                  '支 ${store.money(g.expense)}',
                  style: TextStyle(fontSize: 11.5, color: p.ink2, fontWeight: FontWeight.w700),
                ),
              if (g.expense > 0 && g.income > 0) const SizedBox(width: 8),
              if (g.income > 0)
                Text(
                  '收 ${store.money(g.income)}',
                  style: TextStyle(fontSize: 11.5, color: p.income, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        ...List<Widget>.generate(g.bills.length, (int i) {
          return Column(
            children: <Widget>[
              _billTile(p, store, g.bills[i], i),
              if (i != g.bills.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 66),
                  child: Divider(height: 1, color: p.line, thickness: 1),
                ),
            ],
          );
        }),
      ],
    );
  }

  /// 日期胶囊：作为连续时间轴上的节点，今天用品牌色实心
  Widget _dayPill(Palette p, DateTime day, bool today) {
    return Container(
      width: 40,
      height: 42,
      decoration: BoxDecoration(
        color: today ? p.accent : (p.dark ? Colors.white.withOpacity(0.06) : p.cardSoft),
        borderRadius: BorderRadius.circular(R.m),
        boxShadow: today ? p.accentGlow : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 16,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: today ? Colors.white : p.ink,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            weekdayCn(day),
            style: TextStyle(
              fontSize: 8.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: today ? Colors.white.withOpacity(0.85) : p.ink3,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final DateTime now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// 分类小标签：只在有备注时出现，避免与标题重复
  Widget _catChip(Palette p, CategoryDef c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.color.withOpacity(p.dark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        c.name,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c.color, height: 1.2),
      ),
    );
  }

  Widget _billTile(Palette p, AppStore store, Bill b, int i) {
    final CategoryDef c = catById(b.catId);
    final String title = b.note.isEmpty ? c.name : b.note;
    return Dismissible(
      key: ValueKey<String>(b.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: p.expense.withOpacity(0.12),
          borderRadius: BorderRadius.circular(R.m),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: p.expense, size: 22),
      ),
      confirmDismiss: (DismissDirection _) async {
        HapticFeedback.mediumImpact();
        return _confirmDelete(context);
      },
      onDismissed: (DismissDirection _) {
        final Bill? removed = store.removeBill(b.id);
        if (removed != null) {
          showToast(context, '已删除「$title」', icon: Icons.delete_rounded);
        }
      },
      child: Pressable(
        scale: 0.99,
        onLongPress: () => _showActions(b),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          child: Row(
            children: <Widget>[
              // 点分类气泡 → 单独换分类
              GestureDetector(
                onTap: () => _editCategory(b),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CatBubble(cat: c, size: 40, iconSize: 19),
                ),
              ),
              // 点标题/副标题 → 打开编辑整笔
              Expanded(
                child: GestureDetector(
                  onTap: () => _openEdit(b),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.note.isNotEmpty) ...<Widget>[
                            const SizedBox(width: 6),
                            _catChip(p, c),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        timeLabel(b.date),
                        style: TextStyle(fontSize: 11, color: p.ink3, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 点金额 → 弹出独立数字键盘
              GestureDetector(
                onTap: () => _editAmount(b),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 84),
                    child: Text(
                      '${b.expense ? '-' : '+'}${store.money(b.amount)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: b.expense ? p.ink : p.income,
                        letterSpacing: -0.4,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 行内快捷编辑

  Future<void> _editCategory(Bill b) async {
    HapticFeedback.selectionClick();
    final AppStore store = AppScope.storeOf(context);
    final String? picked = await showCategoryPicker(
      context,
      expense: b.expense,
      current: b.catId,
      recent: store.recentCatIds(expense: b.expense),
    );
    if (picked == null || picked == b.catId || !mounted) return;
    store.updateBill(b.copyWith(catId: picked));
    if (mounted) {
      showToast(context, '已改为「${catById(picked).name}」', icon: Icons.category_rounded);
    }
  }

  Future<void> _editNote(Bill b) async {
    HapticFeedback.selectionClick();
    final AppStore store = AppScope.storeOf(context);
    final String? note = await showNotePicker(
      context,
      store: store,
      catId: b.catId,
      expense: b.expense,
      initial: b.note,
    );
    if (note == null || !mounted) return;
    store.updateBill(b.copyWith(note: note));
    if (mounted) showToast(context, '备注已更新');
  }

  Future<void> _editAmount(Bill b) async {
    HapticFeedback.selectionClick();
    final AppStore store = AppScope.storeOf(context);
    final double? v = await showAmountKeypad(context, initial: b.amount, expense: b.expense);
    if (v == null || v <= 0 || !mounted) return;
    store.updateBill(b.copyWith(amount: v));
    if (mounted) showToast(context, '金额已改为 ${store.money(v)}', icon: Icons.payments_rounded);
  }

  Future<void> _openEdit(Bill b) async {
    final bool? ok = await showBillSheet(context, bill: b);
    if (ok == true && mounted) showToast(context, '账单已更新');
  }

  Future<void> _showActions(Bill b) async {
    final CategoryDef c = catById(b.catId);
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
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
                  CatBubble(cat: c, size: 42, iconSize: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          b.note.isEmpty ? c.name : b.note,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${b.date.month}月${b.date.day}日 ${timeLabel(b.date)} · ${store.money(b.amount)}',
                          style: TextStyle(fontSize: 11.5, color: p.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _actionTile(
                p,
                icon: Icons.receipt_long_rounded,
                color: p.accent2,
                label: '查看详情',
                onTap: () {
                  Navigator.pop(ctx);
                  _showDetail(b);
                },
              ),
              const SizedBox(height: 10),
              _actionTile(
                p,
                icon: Icons.short_text_rounded,
                color: p.income,
                label: '只改备注',
                onTap: () {
                  Navigator.pop(ctx);
                  _editNote(b);
                },
              ),
              const SizedBox(height: 10),
              _actionTile(
                p,
                icon: Icons.edit_rounded,
                color: p.accent,
                label: '编辑账单',
                onTap: () {
                  Navigator.pop(ctx);
                  _openEdit(b);
                },
              ),
              const SizedBox(height: 10),
              _actionTile(
                p,
                icon: Icons.delete_outline_rounded,
                color: p.expense,
                label: '删除账单',
                onTap: () async {
                  Navigator.pop(ctx);
                  final bool ok = await _confirmDelete(context);
                  if (ok && mounted) {
                    store.removeBill(b.id);
                    showToast(context, '已删除该笔账单', icon: Icons.delete_rounded);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDetail(Bill b) async {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final CategoryDef c = catById(b.catId);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
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
            const SizedBox(height: 20),
            CatBubble(cat: c, size: 62, iconSize: 28),
            const SizedBox(height: 14),
            Text(
              b.note.isEmpty ? c.name : b.note,
              textAlign: TextAlign.center,
              style: T.h2(p).copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              '${c.name} · ${b.expense ? '支出' : '收入'}',
              style: TextStyle(fontSize: 11.5, color: p.ink3),
            ),
            const SizedBox(height: 16),
            Text(
              '${b.expense ? '-' : '+'}${store.money(b.amount)}',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: b.expense ? p.ink : p.income,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.cardSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                '${b.date.year}/${b.date.month}/${b.date.day} '
                '${b.date.hour.toString().padLeft(2, '0')}:${b.date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: p.ink2,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Pressable(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEdit(b);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: p.accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text('编辑',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: p.accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: p.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text('关闭',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: p.ink2)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(Palette p,
      {required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final Palette p = AppScope.paletteOf(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('删除这笔账单？', style: T.h2(p).copyWith(fontSize: 17)),
        content: Text('删除后无法恢复。', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: p.expense, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// 入场渐显动效
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delay;

  const _Reveal({Key? key, required this.child, this.delay = 0}) : super(key: key);

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: a,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, 16 * (1 - a.value)), child: child),
        );
      },
      child: widget.child,
    );
  }
}
