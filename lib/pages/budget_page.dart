import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/charts.dart';
import '../ui/common.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final DateTime now = DateTime.now();
    final List<Bill> monthBills = AppStore.inMonth(store.bills, now);
    final double spent = AppStore.total(monthBills, expense: true);
    final double budget = store.monthlyBudget;
    final double remain = budget - spent;
    final double ratio = budget <= 0 ? 0 : spent / budget;
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int leftDays = (daysInMonth - now.day + 1).clamp(1, 31);
    final double perDay = remain > 0 ? remain / leftDays : 0;
    final Map<String, double> byCat = AppStore.byCategory(monthBills, expense: true);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 132),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('预算管理', style: T.h1(p).copyWith(fontSize: 24)),
              const Spacer(),
              Pressable(
                onTap: () => _editTotalBudget(context, store),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: p.shadow,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.tune_rounded, size: 14, color: p.accent),
                      const SizedBox(width: 5),
                      Text(
                        '设置预算',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              children: <Widget>[
                RingProgress(
                  progress: ratio,
                  size: 208,
                  stroke: 19,
                  warn: ratio > 0.85,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        remain >= 0 ? '剩余可用' : '已超支',
                        style: TextStyle(fontSize: 12, color: p.ink2, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 5),
                      AnimatedMoney(
                        prefix: '¥',
                        value: remain.abs(),
                        style: T.num(p, 27).copyWith(color: remain >= 0 ? p.ink : p.expense),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: (ratio > 0.85 ? p.expense : p.accent).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '已用 ${(ratio * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: ratio > 0.85 ? p.expense : p.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    _stat(p, '本月预算', store.money(budget), p.ink),
                    Container(width: 1, height: 26, color: p.line),
                    _stat(p, '已支出', store.money(spent), p.expense),
                    Container(width: 1, height: 26, color: p.line),
                    _stat(p, '日均可用', store.money(perDay), p.income),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (ratio > 0.8)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: p.expense.withOpacity(0.09),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.expense.withOpacity(0.18)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 18, color: p.expense),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remain >= 0
                          ? '预算已使用 ${(ratio * 100).toStringAsFixed(0)}%，本月剩余 ${leftDays} 天，注意控制节奏～'
                          : '本月预算已超支 ${store.money(-remain)}，下个月要更留意啦！',
                      style: TextStyle(fontSize: 12, color: p.expense, height: 1.45, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SectionTitle(
            title: '分类预算',
            action: '添加',
            onAction: () => _addCategoryBudget(context, store),
          ),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: <Widget>[
                if (store.budgets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '还没有分类预算，点击右上角「添加」试试',
                      style: TextStyle(fontSize: 12.5, color: p.ink3),
                    ),
                  )
                else
                  ...store.budgets.entries.map((MapEntry<String, double> e) {
                    final CategoryDef c = catById(e.key);
                    final double used = byCat[e.key] ?? 0;
                    final double r = e.value <= 0 ? 0 : used / e.value;
                    final bool over = r > 1;
                    return GestureDetector(
                      onTap: () => _editCategoryBudget(context, store, c.id),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: <Widget>[
                            CatBubble(cat: c, size: 38, iconSize: 18),
                            const SizedBox(width: 11),
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
                                      if (over)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: p.expense.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '超支',
                                            style: TextStyle(fontSize: 9, color: p.expense, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        '¥${fmtAmount(used)} / ${fmtAmount(e.value)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: over ? p.expense : p.ink3,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 0, end: r.clamp(0.0, 1.0)),
                                      duration: const Duration(milliseconds: 800),
                                      curve: Curves.easeOutCubic,
                                      builder: (BuildContext context, double v, Widget? _) {
                                        return LinearProgressIndicator(
                                          value: v,
                                          minHeight: 5,
                                          backgroundColor:
                                              p.dark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F1F7),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            over ? p.expense : c.color,
                                          ),
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
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: p.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.lightbulb_outline_rounded, size: 17, color: p.accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('小贴士', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
                      const SizedBox(height: 4),
                      Text(
                        '建议将月预算拆分成若干分类预算，先控制「餐饮」「购物」这类高频支出，月末更容易达成目标。',
                        style: TextStyle(fontSize: 12, color: p.ink2, height: 1.55),
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

  Widget _stat(Palette p, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 10.5, color: p.ink3)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _editTotalBudget(BuildContext context, AppStore store) async {
    final double? v = await _numberSheet(
      context,
      title: '每月总预算',
      initial: store.monthlyBudget,
      presets: const <double>[3000, 5000, 8000, 12000, 20000],
    );
    if (v != null && v > 0) {
      store.setMonthlyBudget(v);
      if (ctxMounted(context)) showToast(context, '预算已更新');
    }
  }

  static Future<void> _editCategoryBudget(BuildContext context, AppStore store, String catId) async {
    final CategoryDef c = catById(catId);
    final double? v = await _numberSheet(
      context,
      title: '${c.name}预算',
      initial: store.budgets[catId] ?? 500,
      presets: const <double>[300, 500, 800, 1200, 2000],
      onDelete: store.budgets.containsKey(catId)
          ? () {
              store.setCategoryBudget(catId, 0);
              Navigator.of(context).pop();
            }
          : null,
    );
    if (v != null && v > 0) {
      store.setCategoryBudget(catId, v);
      if (ctxMounted(context)) showToast(context, '${c.name}预算已更新');
    }
  }

  static Future<void> _addCategoryBudget(BuildContext context, AppStore store) async {
    final CategoryDef? c = await showModalBottomSheet<CategoryDef>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final Palette p = AppScope.paletteOf(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              Text('选择分类', style: T.h2(p)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: kExpenseCats.length,
                itemBuilder: (BuildContext ctx2, int i) {
                  final CategoryDef cat = kExpenseCats[i];
                  final bool has = store.budgets.containsKey(cat.id);
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, cat),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CatBubble(cat: cat, size: 44, iconSize: 20),
                        const SizedBox(height: 6),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: p.ink2,
                            fontWeight: has ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
    if (c != null && ctxMounted(context)) {
      await _editCategoryBudget(context, store, c.id);
    }
  }

  static Future<double?> _numberSheet(
    BuildContext context, {
    required String title,
    required double initial,
    required List<double> presets,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _BudgetSheet(
        title: title,
        initial: initial,
        presets: presets,
        onDelete: onDelete,
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  final String title;
  final double initial;
  final List<double> presets;
  final VoidCallback? onDelete;

  const _BudgetSheet({
    Key? key,
    required this.title,
    required this.initial,
    required this.presets,
    this.onDelete,
  }) : super(key: key);

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial.toInt().toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final double value = double.tryParse(_ctrl.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.title, style: T.h2(p)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: p.cardSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Text('¥', style: TextStyle(fontSize: 18, color: p.ink2, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.8),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 14)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.presets.map((double v) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _ctrl.text = v.toInt().toString());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.accent.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '¥${fmtAmount(v)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.accent),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                if (widget.onDelete != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        height: 50,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: p.expense.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '删除预算',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.expense),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Pressable(
                    onTap: () => Navigator.pop(context, value),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: p.gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: p.accentGlow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '保存 · ¥${fmtAmount(value)}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
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
}
