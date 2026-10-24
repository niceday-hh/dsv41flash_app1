import 'dart:math' as math;

import 'data.dart';
import 'models.dart';

/// 一条洞察结论
class InsightItem {
  final String id;
  final String title;
  final String value;
  final String summary;
  final String method;
  final List<Bill> bills;
  final bool ready;
  final int tone; // 0 中性 1 偏高 2 良好

  const InsightItem({
    required this.id,
    required this.title,
    required this.value,
    required this.summary,
    required this.method,
    this.bills = const <Bill>[],
    this.ready = true,
    this.tone = 0,
  });
}

class InsightBundle {
  final List<InsightItem> items;
  final double total;
  final double prevTotal;
  final int days;
  final int recordDays;
  final int count;
  final double? projected;
  final double budget;

  const InsightBundle({
    required this.items,
    required this.total,
    required this.prevTotal,
    required this.days,
    required this.recordDays,
    required this.count,
    required this.projected,
    required this.budget,
  });
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

double _sum(Iterable<Bill> list) => list.fold<double>(0, (double s, Bill b) => s + b.amount);

double _median(List<double> values) {
  final List<double> s = List<double>.of(values)..sort();
  if (s.isEmpty) return 0;
  final int i = s.length ~/ 2;
  return s.length.isOdd ? s[i] : (s[i - 1] + s[i]) / 2;
}

String _money(double v) => '¥${v.toStringAsFixed(2)}';

/// 纯本地统计，不依赖网络。区间为 [start, end]（含首尾）。
InsightBundle buildInsights({
  required List<Bill> bills,
  required DateTime start,
  required DateTime end,
  required bool expense,
  required double budget,
  DateTime? nowOverride,
}) {
  final DateTime now = nowOverride ?? DateTime.now();
  final DateTime from = _day(start);
  final DateTime until = _day(end);
  final DateTime tomorrow = _day(now).add(const Duration(days: 1));
  final DateTime observedEnd = until.isBefore(tomorrow) ? until : tomorrow;
  final int days = math.max(0, observedEnd.difference(from).inDays);
  final DateTime prevStart = from.subtract(Duration(days: days));

  bool within(Bill b, DateTime a, DateTime bEnd) {
    final DateTime d = _day(b.date);
    return !d.isBefore(a) && d.isBefore(bEnd) && !b.date.isAfter(now);
  }

  final List<Bill> valid =
      bills.where((Bill b) => b.amount > 0 && b.expense == expense).toList();
  final List<Bill> current = valid.where((Bill b) => within(b, from, observedEnd)).toList();
  final List<Bill> previous = valid.where((Bill b) => within(b, prevStart, from)).toList();
  final double total = _sum(current);
  final double prevTotal = _sum(previous);
  final int recordDays = current.map((Bill b) => _day(b.date)).toSet().length;
  final List<InsightItem> items = <InsightItem>[];

  if (current.isEmpty || days == 0) {
    items.add(InsightItem(
      id: 'empty',
      title: '等待可分析的记录',
      value: '数据不足',
      summary: '所选时段还没有${expense ? '支出' : '收入'}记录。',
      method: '仅统计金额为正、且时间不晚于当前的账单。',
      ready: false,
    ));
    return InsightBundle(
      items: items,
      total: 0,
      prevTotal: 0,
      days: days,
      recordDays: 0,
      count: 0,
      projected: null,
      budget: budget,
    );
  }

  final String periodNote =
      '本期 ${from.month}/${from.day}—${observedEnd.subtract(const Duration(days: 1)).month}/${observedEnd.subtract(const Duration(days: 1)).day}，'
      '与紧邻的前 $days 天等长对比。';

  // 1. 环比
  if (previous.isEmpty || prevTotal <= 0) {
    items.add(InsightItem(
      id: 'change',
      title: '等长时段对比',
      value: '暂无对照',
      summary: '前 $days 天没有记录，无法计算变化率。',
      method: '变化率 = (本期 − 对照) ÷ 对照；不使用未结束的月份与完整上月直接比较。',
      ready: false,
    ));
  } else {
    final double delta = total - prevTotal;
    items.add(InsightItem(
      id: 'change',
      title: '等长时段对比',
      value: '${delta >= 0 ? '+' : ''}${(delta / prevTotal * 100).toStringAsFixed(1)}%',
      summary: '${expense ? '支出' : '收入'}由 ${_money(prevTotal)} 变为 ${_money(total)}，'
          '${delta >= 0 ? '增加' : '减少'} ${_money(delta.abs())}。',
      method: '$periodNote\n变化率 = (本期总额 − 对照总额) ÷ 对照总额。',
      bills: <Bill>[...current, ...previous],
      tone: delta > 0 ? 1 : 2,
    ));

    // 2. 驱动因素
    final Map<String, double> changes = <String, double>{};
    for (final Bill b in current) {
      changes[b.catId] = (changes[b.catId] ?? 0) + b.amount;
    }
    for (final Bill b in previous) {
      changes[b.catId] = (changes[b.catId] ?? 0) - b.amount;
    }
    final List<MapEntry<String, double>> ranked = changes.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.abs().compareTo(a.value.abs()));
    final MapEntry<String, double> top = ranked.first;
    items.add(InsightItem(
      id: 'drivers',
      title: '变化来自哪里',
      value: catById(top.key).name,
      summary: ranked
          .take(3)
          .map((MapEntry<String, double> e) =>
              '${catById(e.key).name} ${e.value >= 0 ? '+' : '-'}${_money(e.value.abs())}')
          .join(' · '),
      method: '$periodNote\n各分类「本期 − 对照」后按绝对变化排序，差额之和等于总额变化。',
      bills: <Bill>[...current, ...previous].where((Bill b) => b.catId == top.key).toList(),
    ));

    // 3. 频次 × 单笔均额
    final double avgNow = total / current.length;
    final double avgPrev = prevTotal / previous.length;
    final double freq = (current.length - previous.length) * (avgNow + avgPrev) / 2;
    final double basket = (avgNow - avgPrev) * (current.length + previous.length) / 2;
    items.add(InsightItem(
      id: 'frequency',
      title: '频次 × 单笔均额',
      value: '${previous.length} → ${current.length} 笔',
      summary: '笔数变化贡献 ${_money(freq)}，单笔均额贡献 ${_money(basket)}。',
      method: '$periodNote\n总额 = 笔数 × 单笔均额。\n'
          '频次贡献 = Δ笔数 × 两期均额均值；均额贡献 = Δ均额 × 两期笔数均值。两项相加等于总额变化。',
      bills: <Bill>[...current, ...previous],
    ));
  }

  // 4. 周末 / 工作日日均
  int weekends = 0;
  for (DateTime d = from; d.isBefore(observedEnd); d = d.add(const Duration(days: 1))) {
    if (d.weekday >= 6) weekends++;
  }
  final int weekdays = days - weekends;
  if (weekends >= 2 && weekdays >= 5 && current.length >= 7) {
    final double we = _sum(current.where((Bill b) => b.date.weekday >= 6)) / weekends;
    final double wd = _sum(current.where((Bill b) => b.date.weekday < 6)) / weekdays;
    items.add(InsightItem(
      id: 'rhythm',
      title: '周末与工作日日均',
      value: wd > 0 ? '${(we / wd).toStringAsFixed(2)} 倍' : '—',
      summary: '周末 ${_money(we)}/日，工作日 ${_money(wd)}/日。',
      method: '分别除以本期 $weekends 个周末日与 $weekdays 个工作日（含无记录日），不校正节假日。',
      bills: current,
      tone: we > wd * 1.5 ? 1 : 0,
    ));
  }

  // 5. 集中度
  final Map<String, double> byCat = <String, double>{};
  for (final Bill b in current) {
    byCat[b.catId] = (byCat[b.catId] ?? 0) + b.amount;
  }
  final List<MapEntry<String, double>> cats = byCat.entries.toList()
    ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));
  final double top3 = cats.take(3).fold<double>(0, (double s, MapEntry<String, double> e) => s + e.value);
  double hhi = 0;
  for (final MapEntry<String, double> e in cats) {
    hhi += (e.value / total) * (e.value / total);
  }
  items.add(InsightItem(
    id: 'concentration',
    title: '${expense ? '支出' : '收入'}集中度',
    value: '${(top3 / total * 100).toStringAsFixed(1)}%',
    summary: '前 ${math.min(3, cats.length)} 个分类占比；等效均匀分类数 ${(1 / hhi).toStringAsFixed(1)}。',
    method: '集中度 H = Σ(分类占比²)，等效分类数 = 1 / H，只描述金额结构，不含健康与否的判断。',
    bills: current,
  ));

  // 6. 疑似周期账单
  final Map<String, List<Bill>> groups = <String, List<Bill>>{};
  for (final Bill b in valid.where((Bill b) =>
      within(b, observedEnd.subtract(const Duration(days: 180)), observedEnd))) {
    final String note = b.note.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (note.isEmpty) continue;
    groups.putIfAbsent('${b.catId}|$note', () => <Bill>[]).add(b);
  }
  final List<String> labels = <String>[];
  final List<Bill> recurringBills = <Bill>[];
  for (final MapEntry<String, List<Bill>> g in groups.entries) {
    final List<Bill> list = g.value..sort((Bill a, Bill b) => a.date.compareTo(b.date));
    if (list.length < 3) continue;
    if (list.map((Bill b) => _day(b.date)).toSet().length != list.length) continue;
    if (!list.any((Bill b) => within(b, from, observedEnd))) continue;
    final List<double> gaps = <double>[
      for (int i = 1; i < list.length; i++) _day(list[i].date).difference(_day(list[i - 1].date)).inDays.toDouble()
    ];
    final double gap = _median(gaps);
    final double amt = _median(list.map((Bill b) => b.amount).toList());
    final bool weekly = gap >= 6 && gap <= 8;
    final bool monthly = gap >= 26 && gap <= 33;
    if (!weekly && !monthly) continue;
    if (gaps.any((double v) => (v - gap).abs() > (weekly ? 1 : 3))) continue;
    if (list.any((Bill b) => (b.amount - amt).abs() > amt * 0.1)) continue;
    final String name = list.last.note.isEmpty ? catById(list.last.catId).name : list.last.note;
    labels.add('$name · 疑似${weekly ? '每周' : '每月'}');
    recurringBills.addAll(list);
  }
  items.add(InsightItem(
    id: 'recurring',
    title: '疑似周期账单',
    value: '${labels.length} 组',
    summary: labels.isEmpty ? '近 180 天内没有发现稳定的周期记录。' : labels.take(3).join('\n'),
    method: '同一分类 + 相同备注，至少 3 次不同日期；间隔中位数 6–8 天或 26–33 天，'
        '各次间隔偏差不超过 1/3 天，金额偏差不超过 10%。属于启发式提示，不一定真的是订阅。',
    bills: recurringBills,
  ));

  // 7. 月末预算情景
  double? projected;
  final bool isCurrentMonth = from.year == now.year && from.month == now.month;
  if (expense && isCurrentMonth && days >= 7 && recordDays >= 4) {
    final int totalDays = DateTime(from.year, from.month + 1, 0).day;
    projected = total / days * totalDays;
    items.add(InsightItem(
      id: 'budget',
      title: '月末预算情景',
      value: _money(projected),
      summary: budget <= 0
          ? '按当前日均延续，尚未设置月预算。'
          : '按当前日均延续，${projected > budget ? '将超出' : '仍在'}月预算 ${_money(budget)}'
              '${projected > budget ? ' ${_money(projected - budget)}' : ' 内'}。',
      method: '已记支出 ÷ 已过天数 × 本月天数，假设记录完整、后续日均稳定，属于情景外推而非预测保证。',
      bills: current,
      tone: budget > 0 ? (projected > budget ? 1 : 2) : 0,
    ));
  }

  return InsightBundle(
    items: items,
    total: total,
    prevTotal: prevTotal,
    days: days,
    recordDays: recordDays,
    count: current.length,
    projected: projected,
    budget: budget,
  );
}
