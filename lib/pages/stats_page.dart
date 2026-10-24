import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/charts.dart';
import '../ui/common.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late DateTime _month;
  bool _yearMode = false;
  bool _expense = true;
  int _selected = -1;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  List<Bill> _periodBills(AppStore store) {
    if (_yearMode) {
      return store.bills.where((Bill b) => b.date.year == _month.year).toList();
    }
    return AppStore.inMonth(store.bills, _month);
  }

  void _shift(int delta) {
    final DateTime now = DateTime.now();
    final DateTime next = _yearMode
        ? DateTime(_month.year + delta, 1, 1)
        : DateTime(_month.year, _month.month + delta, 1);
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    HapticFeedback.selectionClick();
    setState(() {
      _month = next;
      _selected = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final List<Bill> bills = _periodBills(store);
    final double total = AppStore.total(bills, expense: _expense);
    final Map<String, double> byCat = AppStore.byCategory(bills, expense: _expense);
    final List<MapEntry<String, double>> ranked = byCat.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));

    final List<DonutSlice> slices = <DonutSlice>[];
    const List<Color> extraColors = <Color>[
      Color(0xFFFF8A65),
      Color(0xFF5C9DFF),
      Color(0xFFFF6FA5),
      Color(0xFF9B8CFF),
      Color(0xFF4DB6AC),
      Color(0xFFFFA726),
      Color(0xFF26C6DA),
      Color(0xFF90A4AE),
    ];
    int colorIdx = 0;
    for (final MapEntry<String, double> e in ranked.take(5)) {
      slices.add(DonutSlice(e.value, catById(e.key).color, catById(e.key).name));
    }
    if (ranked.length > 5) {
      double rest = 0;
      for (final MapEntry<String, double> e in ranked.skip(5)) {
        rest += e.value;
      }
      slices.add(DonutSlice(rest, extraColors[colorIdx++ % extraColors.length], '其他'));
    }

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
                labels: const <String>['月', '年'],
                index: _yearMode ? 1 : 0,
                compact: true,
                onChanged: (int i) {
                  setState(() {
                    _yearMode = i == 1;
                    _selected = -1;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _totalCard(p, total, bills),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('分类占比', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
                    const Spacer(),
                    Segmented(
                      labels: const <String>['支出', '收入'],
                      index: _expense ? 0 : 1,
                      compact: true,
                      onChanged: (int i) {
                        setState(() {
                          _expense = i == 0;
                          _selected = -1;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (slices.isEmpty)
                  const EmptyState(
                    title: '暂无数据',
                    desc: '记录几笔账单后即可查看分类占比',
                    icon: Icons.pie_chart_rounded,
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      DonutChart(
                        slices: slices,
                        size: 158,
                        stroke: 17,
                        selected: _selected,
                        onSelect: (int i) => setState(() => _selected = i),
                        center: _donutCenter(p, slices, total),
                      ),
                      const SizedBox(width: 12),
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
                const SizedBox(height: 6),
              ],
            ),
          ),
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
                    Text(
                      _yearMode ? '${_month.year}年' : '近 6 个月',
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TrendBars(
                  values: _trendValues(store),
                  labels: _trendLabels(),
                  highlight: _trendValues(store).length - 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('分类排行', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
                    const Spacer(),
                    Text('TOP ${ranked.length.clamp(0, 6)}', style: TextStyle(fontSize: 11.5, color: p.ink3)),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: <Widget>[
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
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(fontSize: 10.5, color: p.ink3),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '¥${fmtAmount(e.value.value)}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: p.ink,
                                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                      ),
                                    ),
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
                                        backgroundColor: p.dark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F1F7),
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
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _insightCard(p, ranked, total),
        ],
      ),
    );
  }

  Widget _donutCenter(Palette p, List<DonutSlice> slices, double total) {
    if (_selected >= 0 && _selected < slices.length) {
      final DonutSlice s = slices[_selected];
      final double pct = total == 0 ? 0 : s.value / total * 100;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(s.label, style: TextStyle(fontSize: 11.5, color: p.ink2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            '¥${fmtAmount(s.value)}',
            style: TextStyle(
              fontSize: 17,
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
          '¥${fmtAmount(total)}',
          style: TextStyle(
            fontSize: 19,
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

  Widget _totalCard(Palette p, double total, List<Bill> bills) {
    final int count = bills.where((Bill b) => b.expense == _expense).length;
    final int days = _yearMode ? 365 : DateTime(_month.year, _month.month + 1, 0).day;
    final double avg = total / days;
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
              GestureDetector(
                onTap: () => _shift(-1),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.chevron_left_rounded, size: 18, color: p.ink2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _yearMode ? '${_month.year}年' : monthLabel(_month),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _shift(1),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                ),
              ),
              const Spacer(),
              Text('共 $count 笔', style: TextStyle(fontSize: 11.5, color: p.ink3)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '¥',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink2),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: AnimatedMoney(value: total, style: T.num(p, 34)),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.insights_rounded, size: 12, color: p.ink3),
              const SizedBox(width: 4),
              Text(
                '日均 ¥${fmtAmount(avg)}',
                style: TextStyle(fontSize: 11.5, color: p.ink2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _trendValues(AppStore store) {
    if (_yearMode) {
      final List<double> out = <double>[];
      for (int m = 1; m <= 12; m++) {
        final DateTime mm = DateTime(_month.year, m, 1);
        out.add(AppStore.total(AppStore.inMonth(store.bills, mm), expense: true));
      }
      return out;
    }
    final List<double> out = <double>[];
    for (int i = 5; i >= 0; i--) {
      final DateTime mm = DateTime(_month.year, _month.month - i, 1);
      out.add(AppStore.total(AppStore.inMonth(store.bills, mm), expense: true));
    }
    return out;
  }

  List<String> _trendLabels() {
    if (_yearMode) {
      return List<String>.generate(12, (int i) => '${i + 1}');
    }
    final List<String> out = <String>[];
    for (int i = 5; i >= 0; i--) {
      final DateTime mm = DateTime(_month.year, _month.month - i, 1);
      out.add('${mm.month}月');
    }
    return out;
  }

  Widget _insightCard(Palette p, List<MapEntry<String, double>> ranked, double total) {
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
                      TextSpan(text: '」是你的最大开销项，共 ¥${fmtAmount(ranked.first.value)}，占比 ${pct.toStringAsFixed(1)}%。'),
                      TextSpan(
                        text: pct > 45 ? ' 稍微控制一下会更好哦～' : ' 保持得不错，继续加油！',
                      ),
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
}
