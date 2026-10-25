import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../calendar/date_info.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// 报表页的日历视图：跟随当前统计周期（周 / 月 / 季 / 年）。
///
/// - 周：7 天横条，直接显示每天金额
/// - 月：标准月历，按当日金额深浅着色，并标注节气 / 节日
/// - 季 / 年：多月缩略网格，只看色块分布
class PeriodCalendar extends StatelessWidget {
  const PeriodCalendar({
    Key? key,
    required this.start,
    required this.end,
    required this.periodIndex,
    required this.bills,
    required this.expense,
    this.onMonthTap,
    this.onDayTap,
  }) : super(key: key);

  final DateTime start;
  final DateTime end;
  final int periodIndex;
  final List<Bill> bills;
  final bool expense;

  /// 季 / 年缩略网格中点某个月时触发（通常跳到该月全页日历）
  final ValueChanged<DateTime>? onMonthTap;

  /// 周 / 月视图点某一天时触发（查看当天明细）
  final ValueChanged<DateTime>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final Map<int, double> totals = dailyTotals(bills, start, end, expense: expense);
    final double maxV = totals.values.fold<double>(0, math.max);

    if (periodIndex == 0) return _weekView(p, totals, maxV);
    if (periodIndex == 1) return _monthView(p, totals, maxV, DateTime(start.year, start.month, 1));
    return _multiMonth(p, totals, maxV);
  }

  // ---------------------------------------------------------------- 周

  Widget _weekView(Palette p, Map<int, double> totals, double maxV) {
    final Color tint = expense ? p.expense : p.income;
    final List<Widget> cols = <Widget>[];
    for (int i = 0; i < 7; i++) {
      final DateTime d = DateTime(start.year, start.month, start.day + i);
      final double v = totals[_dayKey(d)] ?? 0;
      final double ratio = maxV <= 0 ? 0 : (v / maxV).clamp(0.0, 1.0);
      final DateInfo info = dateInfoOf(d);
      cols.add(
        Expanded(
          child: GestureDetector(
            onTap: onDayTap == null ? null : () => onDayTap!(d),
            behavior: HitTestBehavior.opaque,
            child: Column(
            children: <Widget>[
              Text(
                const <String>['一', '二', '三', '四', '五', '六', '日'][i],
                style: TextStyle(fontSize: 10.5, color: p.ink3, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                height: 96,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: v <= 0 ? p.cardSoft : tint.withOpacity(0.08 + ratio * 0.52),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (v > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: ratio > 0.55 ? Colors.white : p.ink2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: info.weekend ? p.accent : p.ink2,
                ),
              ),
              if (info.label != null)
                Text(
                  info.label!,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 8, color: p.ink3),
                )
              else
                const SizedBox(height: 10),
            ],
          ),
          ),
        ),
      );
    }
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(children: cols),
          const SizedBox(height: 8),
          _legend(p),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 月

  Widget _monthView(Palette p, Map<int, double> totals, double maxV, DateTime month) {
    final Color tint = expense ? p.expense : p.income;
    final int days = DateTime(month.year, month.month + 1, 0).day;
    final int lead = DateTime(month.year, month.month, 1).weekday - 1; // 周一为 0
    final List<Widget?> cells = <Widget?>[
      for (int i = 0; i < lead; i++) null,
    ];

    double monthTotal = 0;
    for (int d = 1; d <= days; d++) {
      final double v = totals[_dayKey(DateTime(month.year, month.month, d))] ?? 0;
      monthTotal += v;
      final double ratio = maxV <= 0 ? 0 : (v / maxV).clamp(0.0, 1.0);
      final DateInfo info = dateInfoOf(DateTime(month.year, month.month, d));
      cells.add(
        GestureDetector(
          onTap: onDayTap == null
              ? null
              : () => onDayTap!(DateTime(month.year, month.month, d)),
          behavior: HitTestBehavior.opaque,
          child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: v <= 0 ? p.cardSoft : tint.withOpacity(0.08 + ratio * 0.55),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$d',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ratio > 0.62 ? Colors.white : (info.weekend ? p.accent : p.ink),
                ),
              ),
              if (info.label != null)
                Text(
                  info.label!,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 7.5,
                    height: 1.1,
                    color: ratio > 0.62 ? Colors.white.withOpacity(0.9) : p.ink3,
                  ),
                ),
            ],
          ),
          ),
        ),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('${month.month}月', style: T.h2(p).copyWith(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                expense ? '支出 ${'¥${fmtAmount(monthTotal)}'}' : '收入 ${'¥${fmtAmount(monthTotal)}'}',
                style: TextStyle(fontSize: 11, color: p.ink3),
              ),
              const Spacer(),
              if (!hasTermData(month.year))
                Text('${month.year} 年无节气资料', style: TextStyle(fontSize: 9.5, color: p.ink3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const <String>['一', '二', '三', '四', '五', '六', '日']
                .map((String s) => Expanded(
                      child: Center(
                        child: Text(s,
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF9AA0B4))),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.86,
            children: <Widget>[
              for (final Widget? c in cells)
                c ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
          _legend(p),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 季 / 年

  Widget _multiMonth(Palette p, Map<int, double> totals, double maxV) {
    final Color tint = expense ? p.expense : p.income;
    final List<DateTime> months = <DateTime>[];
    for (DateTime m = DateTime(start.year, start.month, 1);
        m.isBefore(DateTime(end.year, end.month + 1, 1));
        m = DateTime(m.year, m.month + 1, 1)) {
      months.add(m);
    }
    final bool compact = months.length > 4;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: compact ? 10 : 14,
            runSpacing: 14,
            children: months.map((DateTime m) {
              final int days = DateTime(m.year, m.month + 1, 0).day;
              final int lead = DateTime(m.year, m.month, 1).weekday - 1;
              double total = 0;
              for (int d = 1; d <= days; d++) {
                total += totals[_dayKey(DateTime(m.year, m.month, d))] ?? 0;
              }
              final Widget block = SizedBox(
                width: compact ? 78 : 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('${m.month}月',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: p.ink2)),
                        if (onMonthTap != null) ...<Widget>[
                          const SizedBox(width: 2),
                          Icon(Icons.north_east_rounded, size: 9, color: p.ink3),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: <Widget>[
                        for (int i = 0; i < lead; i++)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        for (int d = 1; d <= days; d++)
                          _miniCell(
                            p,
                            tint,
                            totals[_dayKey(DateTime(m.year, m.month, d))] ?? 0,
                            maxV,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total <= 0 ? '—' : '¥${fmtAmount(total)}',
                      style: TextStyle(fontSize: 9.5, color: p.ink3),
                    ),
                  ],
                ),
              );
              if (onMonthTap == null) return block;
              return GestureDetector(
                onTap: () => onMonthTap!(m),
                behavior: HitTestBehavior.opaque,
                child: block,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _legend(p),
        ],
      ),
    );
  }

  Widget _miniCell(Palette p, Color tint, double v, double maxV) {
    final double ratio = maxV <= 0 ? 0 : (v / maxV).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: v <= 0 ? p.cardSoft : tint.withOpacity(0.08 + ratio * 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _legend(Palette p) {
    final Color tint = expense ? p.expense : p.income;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text('少', style: TextStyle(fontSize: 8.5, color: p.ink3)),
        const SizedBox(width: 4),
        for (final double o in <double>[0.10, 0.26, 0.42, 0.62])
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: tint.withOpacity(o),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        Text('多', style: TextStyle(fontSize: 8.5, color: p.ink3)),
      ],
    );
  }
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// 把账单按天汇总
Map<int, double> dailyTotals(List<Bill> bills, DateTime start, DateTime end, {required bool expense}) {
  final DateTime from = DateTime(start.year, start.month, start.day);
  final DateTime to = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
  final Map<int, double> out = <int, double>{};
  for (final Bill b in bills) {
    if (b.expense != expense) continue;
    final DateTime d = DateTime(b.date.year, b.date.month, b.date.day);
    if (d.isBefore(from) || !d.isBefore(to)) continue;
    final int k = _dayKey(d);
    out[k] = (out[k] ?? 0) + b.amount;
  }
  return out;
}
