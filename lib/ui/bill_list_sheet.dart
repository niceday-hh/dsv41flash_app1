import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'add_sheet.dart';
import 'common.dart';

/// 半屏账单列表：用于日历点某天、趋势点某个节点后查看具体条目。
Future<void> showBillListSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<Bill> bills,
  required AppStore store,
}) {
  final List<Bill> sorted = List<Bill>.of(bills)
    ..sort((Bill a, Bill b) => b.date.compareTo(a.date));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      final Palette p = AppScope.paletteOf(ctx);
      double expenseSum = 0;
      double incomeSum = 0;
      for (final Bill b in sorted) {
        if (b.expense) {
          expenseSum += b.amount;
        } else {
          incomeSum += b.amount;
        }
      }
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.68),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: T.h2(p).copyWith(fontSize: 17)),
                        const SizedBox(height: 3),
                        Text(
                          subtitle ?? '${sorted.length} 笔',
                          style: TextStyle(fontSize: 11.5, color: p.ink2),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(15)),
                      child: Icon(Icons.close_rounded, size: 16, color: p.ink2),
                    ),
                  ),
                ],
              ),
            ),
            if (sorted.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: <Widget>[
                    if (expenseSum > 0)
                      _sumChip(p, '支出', store.money(expenseSum), p.expense),
                    if (expenseSum > 0 && incomeSum > 0) const SizedBox(width: 8),
                    if (incomeSum > 0) _sumChip(p, '收入', store.money(incomeSum), p.income),
                  ],
                ),
              ),
            Divider(height: 1, color: p.line),
            Flexible(
              child: sorted.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.receipt_long_rounded, size: 30, color: p.ink3),
                            const SizedBox(height: 10),
                            Text('这段时间还没有记录',
                                style: TextStyle(fontSize: 12.5, color: p.ink3)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                      itemCount: sorted.length,
                      separatorBuilder: (BuildContext c, int i) =>
                          Divider(height: 1, color: p.line.withOpacity(0.7)),
                      itemBuilder: (BuildContext c, int i) {
                        final Bill b = sorted[i];
                        final CategoryDef c0 = catById(b.catId);
                        return Pressable(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await showBillSheet(context, bill: b);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(
                              children: <Widget>[
                                CatBubble(cat: c0, size: 34, iconSize: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        b.note.isEmpty ? c0.name : b.note,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: p.ink),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${b.date.month}月${b.date.day}日 '
                                        '${b.date.hour.toString().padLeft(2, '0')}:'
                                        '${b.date.minute.toString().padLeft(2, '0')} · ${c0.name}',
                                        style: TextStyle(fontSize: 10.5, color: p.ink3),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${b.expense ? '-' : '+'}${store.money(b.amount)}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: b.expense ? p.ink : p.income,
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
}

Widget _sumChip(Palette p, String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(width: 5),
        Text(value,
            style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
