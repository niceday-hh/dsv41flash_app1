import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data.dart';
import '../insight.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/add_sheet.dart';
import '../ui/common.dart';

/// 消费洞察页：多维分析 + 计算依据 + 关联账单 + 预算情景
class InsightPage extends StatefulWidget {
  final DateTime start;
  final DateTime end;
  final String periodLabel;

  const InsightPage({
    Key? key,
    required this.start,
    required this.end,
    required this.periodLabel,
  }) : super(key: key);

  @override
  State<InsightPage> createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage> {
  bool _expense = true;
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final InsightBundle bundle = buildInsights(
      bills: store.bills,
      start: widget.start,
      end: widget.end,
      expense: _expense,
      budget: store.monthlyBudget,
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 18, 8),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('消费洞察', style: T.h2(p).copyWith(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          widget.periodLabel,
                          style: TextStyle(fontSize: 11, color: p.ink3),
                        ),
                      ],
                    ),
                  ),
                  Segmented(
                    labels: const <String>['支出', '收入'],
                    index: _expense ? 0 : 1,
                    compact: true,
                    segWidth: 46,
                    onChanged: (int i) => setState(() {
                      _expense = i == 0;
                      _expanded.clear();
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  _summaryCard(p, store, bundle),
                  const SizedBox(height: 12),
                  ...bundle.items.map((InsightItem item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _insightCard(p, store, item),
                      )),
                  if (bundle.projected != null && bundle.budget > 0)
                    _scenarioCard(p, store, bundle),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '以上结论均由本地账单计算，不上传任何数据',
                      style: TextStyle(fontSize: 10.5, color: p.ink3),
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

  Widget _summaryCard(Palette p, AppStore store, InsightBundle b) {
    final double avg = b.days == 0 ? 0 : b.total / b.days;
    return SoftCard(
      gradient: LinearGradient(
        colors: <Color>[p.accent, p.accent2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _expense ? '本期支出' : '本期收入',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 4),
          AnimatedMoney(
            prefix: '¥',
            value: b.total,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.4,
              height: 1.1,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _miniStat('${b.count} 笔'),
              _dot(),
              _miniStat('${b.recordDays} 个记账日'),
              _dot(),
              _miniStat('日均 ${_money(avg)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: Colors.white.withOpacity(0.5))),
      );

  Widget _miniStat(String text) => Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w500),
      );

  Widget _insightCard(Palette p, AppStore store, InsightItem item) {
    final bool open = _expanded.contains(item.id);
    final Color tone = item.tone == 1 ? p.expense : (item.tone == 2 ? p.income : p.accent);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(item.title, style: TextStyle(fontSize: 12.5, color: p.ink2, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!item.ready)
                Text('数据不足', style: TextStyle(fontSize: 10.5, color: p.ink3)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            item.value,
            style: TextStyle(
              fontSize: item.value.length > 9 ? 19 : 23,
              fontWeight: FontWeight.w700,
              color: p.ink,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.summary,
            style: TextStyle(fontSize: 12, color: p.ink2, height: 1.55),
          ),
          if (item.guide.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: p.accent.withOpacity(0.055),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 13, color: p.accent.withOpacity(0.85)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.guide,
                      style: TextStyle(fontSize: 11.5, color: p.ink2, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => setState(() {
                  open ? _expanded.remove(item.id) : _expanded.add(item.id);
                }),
                child: Row(
                  children: <Widget>[
                    Icon(
                      open ? Icons.remove_circle_outline_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: p.ink3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '计算依据',
                      style: TextStyle(fontSize: 11, color: p.ink3, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (item.bills.isNotEmpty) ...<Widget>[
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => _showBills(context, store, item),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.receipt_long_rounded, size: 13, color: p.accent),
                      const SizedBox(width: 4),
                      Text(
                        '关联账单 ${item.bills.length}',
                        style: TextStyle(fontSize: 11, color: p.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(
                item.method,
                style: TextStyle(fontSize: 11, color: p.ink2, height: 1.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scenarioCard(Palette p, AppStore store, InsightBundle b) {
    final double projected = b.projected!;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.tune_rounded, size: 15, color: p.accent),
              const SizedBox(width: 6),
              Text('预算情景', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
              const Spacer(),
              Text('自动外推 ${_money(projected)}', style: TextStyle(fontSize: 10.5, color: p.ink3)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '把剩余每天的支出整体下调，看看月末能不能压回预算内：',
            style: TextStyle(fontSize: 11.5, color: p.ink2, height: 1.6),
          ),
          const SizedBox(height: 6),
          _ScenarioSlider(
            store: store,
            start: widget.start,
            end: widget.end,
            projected: projected,
            budget: b.budget,
          ),
        ],
      ),
    );
  }

  void _showBills(BuildContext context, AppStore store, InsightItem item) {
    final List<Bill> list = List<Bill>.of(item.bills)..sort((Bill a, Bill b) => b.date.compareTo(a.date));
    final Palette p = AppScope.paletteOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: <Widget>[
                    Text('${item.title} · 关联账单', style: T.h2(p).copyWith(fontSize: 16)),
                    const Spacer(),
                    Text('${list.length} 笔', style: TextStyle(fontSize: 11.5, color: p.ink3)),
                  ],
                ),
              ),
              Divider(height: 1, color: p.line),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
                  itemCount: list.length,
                  separatorBuilder: (BuildContext c, int i) => Divider(height: 1, color: p.line),
                  itemBuilder: (BuildContext c, int i) {
                    final Bill bill = list[i];
                    final CategoryDef cat = catById(bill.catId);
                    return Pressable(
                      onTap: () async {
                        Navigator.pop(ctx);
                        final bool? ok = await showBillSheet(context, bill: bill);
                        if (ok == true && mounted) showToast(context, '账单已更新');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: <Widget>[
                            CatBubble(cat: cat, size: 34, iconSize: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                bill.note.isEmpty ? cat.name : bill.note,
                                style: TextStyle(fontSize: 13, color: p.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${bill.date.month}/${bill.date.day}',
                              style: TextStyle(fontSize: 11, color: p.ink3),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              store.money(bill.amount),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
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
  }

  static String _money(double v) => '¥${v.toStringAsFixed(2)}';
}

class _ScenarioSlider extends StatefulWidget {
  final AppStore store;
  final DateTime start;
  final DateTime end;
  final double projected;
  final double budget;

  const _ScenarioSlider({
    Key? key,
    required this.store,
    required this.start,
    required this.end,
    required this.projected,
    required this.budget,
  }) : super(key: key);

  @override
  State<_ScenarioSlider> createState() => _ScenarioSliderState();
}

class _ScenarioSliderState extends State<_ScenarioSlider> {
  double _cut = 0.2;

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final double saved = widget.projected * _cut;
    final double after = widget.projected - saved;
    final bool ok = after <= widget.budget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: p.accent,
            inactiveTrackColor: p.dark ? Colors.white.withOpacity(0.08) : const Color(0xFFEDEEF6),
            thumbColor: Colors.white,
            overlayColor: p.accent.withOpacity(0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 3),
          ),
          child: Slider(
            value: _cut,
            min: 0,
            max: 0.6,
            divisions: 12,
            onChanged: (double v) => setState(() => _cut = v),
          ),
        ),
        Row(
          children: <Widget>[
            Text('下调 ${(_cut * 100).round()}%', style: TextStyle(fontSize: 11.5, color: p.ink2)),
            const Spacer(),
            Text(
              '预计月末 ${_fmt(after)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ok ? p.income : p.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: (ok ? p.income : p.expense).withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ok
                ? '这样能省下 ${_fmt(saved)}，可回到预算 ${_fmt(widget.budget)} 之内。'
                : '仍超出预算 ${_fmt(after - widget.budget)}，需要再压一压。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: ok ? p.income : p.expense,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) => '¥${v.toStringAsFixed(0)}';
}
