import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/add_sheet.dart';
import '../ui/common.dart';

/// 消费日历：月历热力 + 当日明细
class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key, this.initialMonth}) : super(key: key);

  /// 指定进入时展示的月份（用于从季度 / 年度缩略网格点进来）
  final DateTime? initialMonth;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final DateTime base = widget.initialMonth ?? now;
    _month = DateTime(base.year, base.month, 1);
    _selected = (base.year == now.year && base.month == now.month) ? now.day : 0;
  }

  void _shift(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _selected = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final int days = DateTime(_month.year, _month.month + 1, 0).day;
    final int offset = DateTime(_month.year, _month.month, 1).weekday - 1;

    final Map<int, List<Bill>> byDay = <int, List<Bill>>{};
    for (final Bill b in store.bills) {
      if (b.date.year != _month.year || b.date.month != _month.month) continue;
      byDay.putIfAbsent(b.date.day, () => <Bill>[]).add(b);
    }
    final Map<int, double> totals = <int, double>{};
    byDay.forEach((int day, List<Bill> list) {
      totals[day] = AppStore.total(list, expense: true);
    });
    final double maxDay = totals.isEmpty ? 0 : totals.values.reduce(math.max);
    final double monthTotal = totals.values.fold<double>(0, (double s, double v) => s + v);
    final int monthCount = byDay.values.fold<int>(0, (int s, List<Bill> v) => s + v.length);
    final List<Bill> selectedBills = (byDay[_selected] ?? <Bill>[])
      ..sort((Bill a, Bill b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 16, 4),
              child: Row(
                children: <Widget>[
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: p.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('消费日历', style: T.h2(p).copyWith(fontSize: 18)),
                  ),
                  Pressable(
                    onTap: () => _shift(-1),
                    child: Icon(Icons.chevron_left_rounded, size: 24, color: p.ink2),
                  ),
                  SizedBox(
                    width: 92,
                    child: Center(
                      child: Text(
                        '${_month.year}/${_month.month}',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink),
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: () => _shift(1),
                    child: Icon(Icons.chevron_right_rounded, size: 24, color: p.ink3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: const <String>['一', '二', '三', '四', '五', '六', '日']
                              .map((String w) => Expanded(
                                    child: Center(
                                      child: Text(
                                        w,
                                        style: TextStyle(fontSize: 10.5, color: Color(0xFF9AA0B8)),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        _grid(p, store, days, offset, totals, maxDay),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      _statChip(p, '本月支出', store.money(monthTotal), p.expense),
                      const SizedBox(width: 8),
                      _statChip(p, '笔数', '$monthCount', p.accent),
                      const SizedBox(width: 8),
                      _statChip(p, '最高单日', store.money(maxDay), p.income),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SectionTitle(
                    title: _selected == 0
                        ? '选择一天查看明细'
                        : '${_month.month}月$_selected日 · ${selectedBills.length} 笔',
                    trailing: _selected == 0
                        ? null
                        : Text(
                            store.money(AppStore.total(selectedBills, expense: true)),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                  ),
                  if (_selected == 0)
                    EmptyState(
                      title: '点日历里的日期',
                      desc: '可以查看那一天的每一笔收支',
                      icon: Icons.calendar_month_rounded,
                    )
                  else if (selectedBills.isEmpty)
                    EmptyState(
                      title: '这天没有记账',
                      desc: '空白的日子也是生活的一部分',
                      icon: Icons.wb_sunny_rounded,
                    )
                  else
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: List<Widget>.generate(selectedBills.length, (int i) {
                          final Bill b = selectedBills[i];
                          final CategoryDef c = catById(b.catId);
                          return Column(
                            children: <Widget>[
                              Pressable(
                                scale: 0.99,
                                onTap: () async {
                                  final bool? ok = await showBillSheet(context, bill: b);
                                  if (ok == true && mounted) {
                                    showToast(context, '账单已更新');
                                    setState(() {});
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                                  child: Row(
                                    children: <Widget>[
                                      CatBubble(cat: c, size: 38, iconSize: 18),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              b.note.isEmpty ? c.name : b.note,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: p.ink,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${timeLabel(b.date)} · ${c.name}',
                                              style: TextStyle(fontSize: 10.5, color: p.ink3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${b.expense ? '-' : '+'}${store.money(b.amount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: b.expense ? p.ink : p.income,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (i != selectedBills.length - 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 63),
                                  child: Divider(height: 1, color: p.line),
                                ),
                            ],
                          );
                        }),
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

  Widget _statChip(Palette p, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), boxShadow: p.shadow),
        child: Column(
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 10, color: p.ink3)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(Palette p, AppStore store, int days, int offset, Map<int, double> totals, double maxDay) {
    final int cells = ((offset + days) / 7).ceil() * 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.78,
      ),
      itemCount: cells,
      itemBuilder: (BuildContext context, int i) {
        final int day = i - offset + 1;
        if (day < 1 || day > days) return const SizedBox.shrink();
        final double amount = totals[day] ?? 0;
        final bool selected = day == _selected;
        final double intensity = store.hideAmounts
            ? (amount > 0 ? 0.34 : 0)
            : ((maxDay <= 0 || amount <= 0) ? 0 : (amount / maxDay).clamp(0.12, 1.0));
        final DateTime date = DateTime(_month.year, _month.month, day);
        final bool isToday = _isToday(date);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selected = day);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected
                  ? p.accent
                  : (amount > 0
                      ? p.accent.withOpacity(p.dark ? 0.10 + intensity * 0.45 : 0.06 + intensity * 0.30)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(11),
              border: isToday && !selected
                  ? Border.all(color: p.accent.withOpacity(0.55), width: 1.2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : p.ink2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  store.hideAmounts
                      ? (amount > 0 ? '·' : '')
                      : (amount > 0 ? _short(amount) : ''),
                  style: TextStyle(
                    fontSize: 8.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white.withOpacity(0.9) : p.ink2.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime d) {
    final DateTime now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _short(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
