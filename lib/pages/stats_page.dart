import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/add_sheet.dart';
import '../ui/charts.dart';
import '../ui/common.dart';
import '../ui/period_calendar.dart';
import 'calendar_page.dart';
import 'insight_page.dart';

const List<String> _periodNames = <String>['周', '月', '季', '年'];

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _period = 1; // 0 周 1 月 2 季 3 年
  late DateTime _anchor;
  bool _expense = true;
  int _view = 0; // 0 统计 1 日历
  int _selected = -1;
  int _point = -1; // 趋势图选中的节点

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
  }

  // ------------------------------------------------------------- 区间计算

  DateTime get _start {
    switch (_period) {
      case 0:
        final DateTime d = DateTime(_anchor.year, _anchor.month, _anchor.day);
        return d.subtract(Duration(days: d.weekday - 1));
      case 2:
        final int qm = ((_anchor.month - 1) ~/ 3) * 3 + 1;
        return DateTime(_anchor.year, qm, 1);
      case 3:
        return DateTime(_anchor.year, 1, 1);
      default:
        return DateTime(_anchor.year, _anchor.month, 1);
    }
  }

  DateTime get _end {
    switch (_period) {
      case 0:
        return _start.add(const Duration(days: 6));
      case 2:
        return DateTime(_start.year, _start.month + 3, 0);
      case 3:
        return DateTime(_start.year, 12, 31);
      default:
        return DateTime(_start.year, _start.month + 1, 0);
    }
  }

  String get _label {
    switch (_period) {
      case 0:
        final DateTime s = _start;
        final DateTime e = _end;
        return '${s.month}月${s.day}日 - ${e.month}月${e.day}日';
      case 2:
        return '${_start.year} 年 第${((_start.month - 1) ~/ 3) + 1}季度';
      case 3:
        return '${_start.year} 年';
      default:
        return '${_start.year}年${_start.month}月';
    }
  }

  bool get _isCurrent {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(_start) && !today.isAfter(_end);
  }

  void _shift(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_period) {
        case 0:
          _anchor = _anchor.add(Duration(days: 7 * delta));
          break;
        case 2:
          _anchor = DateTime(_anchor.year, _anchor.month + 3 * delta, 1);
          break;
        case 3:
          _anchor = DateTime(_anchor.year + delta, 1, 1);
          break;
        default:
          _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      }
      _selected = -1;
    });
  }

  void _openMonth(DateTime m) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(PageRouteBuilder<bool>(
      pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) =>
          CalendarPage(initialMonth: m),
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
  }

  void _backToCurrent() {
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = DateTime.now();
      _selected = -1;
    });
  }

  bool _inRange(DateTime d, DateTime s, DateTime e) {
    final DateTime day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(s) && !day.isAfter(e);
  }

  List<Bill> _periodBills(AppStore store) {
    final DateTime s = _start;
    final DateTime e = _end;
    return store.bills.where((Bill b) => _inRange(b.date, s, e)).toList();
  }

  List<Bill> _prevPeriodBills(AppStore store) {
    final DateTime s = _start;
    final DateTime e = _end;
    final int days = e.difference(s).inDays + 1;
    final DateTime ps = s.subtract(Duration(days: days));
    final DateTime pe = s.subtract(const Duration(days: 1));
    return store.bills.where((Bill b) => _inRange(b.date, ps, pe)).toList();
  }

  double _dayTotal(AppStore store, DateTime day, bool expense) {
    double sum = 0;
    for (final Bill b in store.bills) {
      if (b.expense != expense) continue;
      if (b.date.year == day.year && b.date.month == day.month && b.date.day == day.day) sum += b.amount;
    }
    return sum;
  }

  List<double> _trendValues(AppStore store, bool expense) {
    final List<double> out = <double>[];
    final DateTime s = _start;
    switch (_period) {
      case 0:
        for (int i = 0; i < 7; i++) {
          out.add(_dayTotal(store, s.add(Duration(days: i)), expense));
        }
        break;
      case 2:
        for (int i = 0; i < 3; i++) {
          final DateTime m = DateTime(s.year, s.month + i, 1);
          out.add(AppStore.total(AppStore.inMonth(store.bills, m), expense: expense));
        }
        break;
      case 3:
        for (int m = 1; m <= 12; m++) {
          out.add(AppStore.total(AppStore.inMonth(store.bills, DateTime(s.year, m, 1)), expense: expense));
        }
        break;
      default:
        final int days = _end.day;
        final int weeks = (days / 7).ceil();
        for (int w = 0; w < weeks; w++) {
          double sum = 0;
          for (int d = w * 7 + 1; d <= (w + 1) * 7 && d <= days; d++) {
            sum += _dayTotal(store, DateTime(s.year, s.month, d), expense);
          }
          out.add(sum);
        }
    }
    return out;
  }

  List<String> _trendLabels() {
    final DateTime s = _start;
    switch (_period) {
      case 0:
        return <String>['一', '二', '三', '四', '五', '六', '日'];
      case 2:
        return List<String>.generate(3, (int i) => '${s.month + i}月');
      case 3:
        return List<String>.generate(12, (int i) => '${i + 1}');
      default:
        final int weeks = (_end.day / 7).ceil();
        return List<String>.generate(weeks, (int i) => '${i + 1}周');
    }
  }

  // ------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final List<Bill> bills = _periodBills(store);
    final double total = AppStore.total(bills, expense: _expense);
    final double prevTotal = AppStore.total(_prevPeriodBills(store), expense: _expense);
    final double delta = prevTotal <= 0 ? 0 : (total - prevTotal) / prevTotal;
    final Map<String, double> byCat = AppStore.byCategory(bills, expense: _expense);
    final List<MapEntry<String, double>> ranked = byCat.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));

    final List<DonutSlice> slices = <DonutSlice>[];
    for (final MapEntry<String, double> e in ranked.take(5)) {
      slices.add(DonutSlice(e.value, catById(e.key).color, catById(e.key).name));
    }
    if (ranked.length > 5) {
      double rest = 0;
      for (final MapEntry<String, double> e in ranked.skip(5)) {
        rest += e.value;
      }
      slices.add(DonutSlice(rest, const Color(0xFFFFA726), '其他'));
    }

    final List<double> trend = _trendValues(store, _expense);
    final int days = _end.difference(_start).inDays + 1;
    final int count = bills.where((Bill b) => b.expense == _expense).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 132),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('统计分析', style: T.h1(p).copyWith(fontSize: 24)),
              const Spacer(),
              Segmented(
                labels: _periodNames,
                index: _period,
                compact: true,
                segWidth: 40,
                onChanged: (int i) {
                  if (i == _period) return;
                  HapticFeedback.selectionClick();
                  setState(() {
                    _period = i;
                    _anchor = DateTime.now();
                    _selected = -1;
                    _point = -1;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _periodBar(p),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Segmented(
                labels: const <String>['支出分析', '收入分析'],
                index: _expense ? 0 : 1,
                compact: true,
                segWidth: 66,
                onChanged: (int i) {
                  if ((i == 0) == _expense) return;
                  HapticFeedback.selectionClick();
                  setState(() {
                    _expense = i == 0;
                    _selected = -1;
                    _point = -1;
                  });
                },
              ),
              const Spacer(),
              Segmented(
                labels: const <String>['统计', '日历'],
                index: _view,
                compact: true,
                segWidth: 56,
                onChanged: (int i) {
                  if (i == _view) return;
                  HapticFeedback.selectionClick();
                  setState(() => _view = i);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_view == 1) ...<Widget>[
            PeriodCalendar(
              start: _start,
              end: _end,
              periodIndex: _period,
              bills: store.bills,
              expense: _expense,
              onMonthTap: _openMonth,
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                '颜色越深表示当天花费越多 · 格内小字为节气 / 节日',
                style: TextStyle(fontSize: 10.5, color: p.ink3),
              ),
            ),
          ],
          if (_view == 0) ...<Widget>[
            _totalCard(p, store, total, delta, count, days),
          const SizedBox(height: 14),
          if (MediaQuery.sizeOf(context).width >= 600)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _donutCard(p, store, slices, total)),
                const SizedBox(width: 14),
                Expanded(child: _rankCard(p, store, ranked, bills, total)),
              ],
            )
          else ...<Widget>[
            _donutCard(p, store, slices, total),
            const SizedBox(height: 14),
            _rankCard(p, store, ranked, bills, total),
          ],
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: p.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.show_chart_rounded, size: 15, color: p.accent),
                    ),
                    const SizedBox(width: 8),
                    Text('消费趋势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
                    const Spacer(),
                    Text('${_trendLabels().length} 个节点', style: TextStyle(fontSize: 11.5, color: p.ink3)),
                  ],
                ),
                const SizedBox(height: 16),
                TrendBars(
                  values: trend,
                  labels: _trendLabels(),
                  height: 138,
                  highlight: _point >= 0 && _point < trend.length
                      ? _point
                      : (trend.isEmpty
                          ? -1
                          : trend.indexOf(trend.reduce((double a, double b) => a > b ? a : b))),
                  onTap: (int i) => setState(() => _point = _point == i ? -1 : i),
                ),
                if (_point >= 0 && _point < trend.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: p.accent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.place_rounded, size: 13, color: p.accent),
                          const SizedBox(width: 6),
                          Text(
                            _trendLabels()[_point],
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: p.accent),
                          ),
                          const Spacer(),
                          Text(
                            trend[_point] <= 0
                                ? '这个节点暂无记录'
                                : '${_expense ? '支出' : '收入'} ${store.money(trend[_point])}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: trend[_point] <= 0 ? p.ink3 : p.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 14),
          Pressable(
            onTap: () {
              Navigator.of(context).push(PageRouteBuilder<bool>(
                pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) => InsightPage(
                  start: _start,
                  end: _end,
                  periodLabel: _label,
                ),
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
            scale: 0.99,
            child: _insightCard(p, store, ranked, total),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '查看全部洞察 · 计算依据与关联账单',
              style: TextStyle(fontSize: 11, color: p.ink3),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _periodBar(Palette p) {
    return Row(
      children: <Widget>[
        Pressable(
          onTap: () => _shift(-1),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(11), boxShadow: p.shadow),
            child: Icon(Icons.chevron_left_rounded, size: 20, color: p.ink2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _label,
              key: ValueKey<String>(_label),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.2),
            ),
          ),
        ),
        if (!_isCurrent) ...<Widget>[
          Pressable(
            onTap: _backToCurrent,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text('回到本期', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.accent)),
            ),
          ),
        ],
        Pressable(
          onTap: () => _shift(1),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(11), boxShadow: p.shadow),
            child: Icon(Icons.chevron_right_rounded, size: 20, color: p.ink3),
          ),
        ),
      ],
    );
  }

  Widget _donutCenter(Palette p, AppStore store, List<DonutSlice> slices, double total) {
    if (_selected >= 0 && _selected < slices.length) {
      final DonutSlice s = slices[_selected];
      final double pct = total == 0 ? 0 : s.value / total * 100;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(s.label, style: TextStyle(fontSize: 11.5, color: p.ink2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            store.money(s.value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.ink,
              letterSpacing: -0.6,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10.5, color: p.ink3)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_expense ? '总支出' : '总收入', style: TextStyle(fontSize: 11.5, color: p.ink2)),
        const SizedBox(height: 3),
        Text(
          store.money(total),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: p.ink,
            letterSpacing: -0.8,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text('点我查看分类', style: TextStyle(fontSize: 9.5, color: p.ink3)),
      ],
    );
  }

  Widget _totalCard(Palette p, AppStore store, double total, double delta, int count, int days) {
    final double avg = days == 0 ? 0 : total / days;
    final bool up = delta > 0;
    return SoftCard(
      gradient: p.dark
          ? const LinearGradient(
              colors: <Color>[Color(0xFF1B1D2B), Color(0xFF222538)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFAFAFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _expense ? '本期支出' : '本期收入',
                style: TextStyle(fontSize: 12, color: p.ink2, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (up ? p.expense : p.income).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  delta.abs() < 0.0001
                      ? '环比持平'
                      : '环比 ${up ? '↑' : '↓'}${(delta.abs() * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: up ? p.expense : p.income,
                  ),
                ),
              ),
              const Spacer(),
              Text('$count 笔', style: TextStyle(fontSize: 11.5, color: p.ink3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('¥', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink2)),
              ),
              const SizedBox(width: 4),
              Flexible(child: AnimatedMoney(value: total, style: T.num(p, 34))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.insights_rounded, size: 12, color: p.ink3),
              const SizedBox(width: 4),
              Text('日均 ${store.money(avg)}', style: TextStyle(fontSize: 11.5, color: p.ink2)),
              const Spacer(),
              Text('共 $days 天', style: TextStyle(fontSize: 11, color: p.ink3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightCard(Palette p, AppStore store, List<MapEntry<String, double>> ranked, double total) {
    if (ranked.isEmpty) return const SizedBox.shrink();
    final CategoryDef top = catById(ranked.first.key);
    final double pct = total == 0 ? 0 : ranked.first.value / total * 100;
    return SoftCard(
      gradient: LinearGradient(
        colors: <Color>[p.accent.withOpacity(0.14), p.accent2.withOpacity(0.06)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.auto_awesome_rounded, size: 17, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('本期洞察', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12.2, color: p.ink2, height: 1.55),
                    children: <TextSpan>[
                      const TextSpan(text: '「'),
                      TextSpan(
                        text: top.name,
                        style: TextStyle(color: top.color, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '」是你的最大开销项，共 ${store.money(ranked.first.value)}，占比 ${pct.toStringAsFixed(1)}%。',
                      ),
                      TextSpan(text: pct > 45 ? ' 稍微控制一下会更好哦～' : ' 保持得不错，继续加油！'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _drillDown(BuildContext context, AppStore store, CategoryDef cat, List<Bill> periodBills) {
    final List<Bill> items = periodBills
        .where((Bill b) => b.catId == cat.id && b.expense == _expense)
        .toList();
    final double sum = AppStore.total(items, expense: _expense);
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final Palette p = AppScope.paletteOf(ctx);
        int sort = 0;
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setSheet) {
            final List<Bill> sorted = List<Bill>.of(items);
            switch (sort) {
              case 1:
                sorted.sort((Bill a, Bill b) => a.date.compareTo(b.date));
                break;
              case 2:
                sorted.sort((Bill a, Bill b) => b.amount.compareTo(a.amount));
                break;
              case 3:
                sorted.sort((Bill a, Bill b) => a.amount.compareTo(b.amount));
                break;
              default:
                sorted.sort((Bill a, Bill b) => b.date.compareTo(a.date));
            }
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      children: <Widget>[
                        CatBubble(cat: cat, size: 44, iconSize: 21),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(cat.name, style: T.h2(p).copyWith(fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} 笔 · ${store.money(sum)}',
                              style: TextStyle(fontSize: 11.5, color: p.ink2),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Pressable(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration:
                                BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(15)),
                            child: Icon(Icons.close_rounded, size: 16, color: p.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: <Widget>[
                        _sortChip(p, '时间新→旧', 0, sort, (int v) => setSheet(() => sort = v)),
                        _sortChip(p, '时间旧→新', 1, sort, (int v) => setSheet(() => sort = v)),
                        _sortChip(p, '金额高→低', 2, sort, (int v) => setSheet(() => sort = v)),
                        _sortChip(p, '金额低→高', 3, sort, (int v) => setSheet(() => sort = v)),
                      ],
                    ),
                  ),
                  Divider(height: 20, color: p.line),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: sorted.length,
                      separatorBuilder: (BuildContext c, int i) => Divider(height: 1, color: p.line),
                      itemBuilder: (BuildContext c, int i) {
                        final Bill b = sorted[i];
                        final double pct = sum <= 0 ? 0 : b.amount / sum * 100;
                        return Pressable(
                          onTap: () async {
                            Navigator.pop(ctx);
                            final bool? ok = await showBillSheet(context, bill: b);
                            if (ok == true && mounted) showToast(context, '账单已更新');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  '${b.date.month}/${b.date.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.ink3,
                                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    b.note.isEmpty ? cat.name : b.note,
                                    style:
                                        TextStyle(fontSize: 13, color: p.ink, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 10.5, color: p.ink3),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  store.money(b.amount),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _donutCard(Palette p, AppStore store, List<DonutSlice> slices, double total) {
    return SoftCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('分类占比', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_expense ? p.expense : p.income).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _expense ? '支出' : '收入',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _expense ? p.expense : p.income,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (slices.isEmpty)
                  const EmptyState(
                    title: '暂无数据',
                    desc: '记录几笔账单后即可查看分类占比',
                    icon: Icons.pie_chart_rounded,
                  )
                else
                  Row(
                    children: <Widget>[
                      DonutChart(
                        slices: slices,
                        size: 152,
                        stroke: 17,
                        selected: _selected,
                        onSelect: (int i) => setState(() => _selected = i),
                        center: _donutCenter(p, store, slices, total),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: List<Widget>.generate(slices.length, (int i) {
                            final DonutSlice s = slices[i];
                            final bool on = _selected == i;
                            final double pct = total == 0 ? 0 : s.value / total * 100;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selected = _selected == i ? -1 : i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: on ? s.color.withOpacity(0.10) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        s.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                          color: p.ink2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: on ? p.ink : p.ink3,
                                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
  }

  Widget _rankCard(Palette p, AppStore store, List<MapEntry<String, double>> ranked, List<Bill> bills, double total) {
    return SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('分类排行', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
                    const Spacer(),
                    Text(ranked.isEmpty ? '' : '点击查看明细', style: TextStyle(fontSize: 11, color: p.ink3)),
                  ],
                ),
                const SizedBox(height: 14),
                if (ranked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('暂无数据', style: TextStyle(fontSize: 12.5, color: p.ink3)),
                    ),
                  )
                else
                  ...ranked.take(6).toList().asMap().entries.map((MapEntry<int, MapEntry<String, double>> e) {
                    final int i = e.key;
                    final CategoryDef c = catById(e.value.key);
                    final double pct = total == 0 ? 0 : e.value.value / total;
                    return Pressable(
                      onTap: () => _drillDown(context, store, c, bills),
                      scale: 0.99,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 15,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: i < 3 ? p.accent : p.ink3,
                                  height: 1,
                                ),
                              ),
                            ),
                            CatBubble(cat: c, size: 36, iconSize: 17),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        c.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: p.ink,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(pct * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 10.5, color: p.ink3),
                                      ),
                                      const Spacer(),
                                      Text(
                                        store.money(e.value.value),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.ink,
                                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded, size: 15, color: p.ink3),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 0, end: pct.clamp(0.0, 1.0)),
                                      duration: Duration(milliseconds: 600 + i * 90),
                                      curve: Curves.easeOutCubic,
                                      builder: (BuildContext context, double v, Widget? _) {
                                        return LinearProgressIndicator(
                                          value: v,
                                          minHeight: 5,
                                          backgroundColor:
                                              p.dark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F1F7),
                                          valueColor: AlwaysStoppedAnimation<Color>(c.color),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
  }

  Widget _sortChip(Palette p, String label, int value, int current, ValueChanged<int> onTap) {
    final bool on = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? p.accent.withOpacity(0.12) : p.cardSoft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: on ? p.accent.withOpacity(0.5) : Colors.transparent, width: 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? p.accent : p.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
