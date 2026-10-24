import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui/add_sheet.dart';
import '../ui/common.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);
    final List<Bill> results = store.search(_q);
    final double total = AppStore.total(results, expense: true);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.search_rounded, size: 18, color: p.ink3),
                          const SizedBox(width: 7),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              style: TextStyle(fontSize: 14, color: p.ink),
                              cursorColor: p.accent,
                              onChanged: (String v) => setState(() => _q = v),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: '搜索备注、分类或金额',
                                hintStyle: TextStyle(fontSize: 13.5, color: p.ink3),
                              ),
                            ),
                          ),
                          if (_q.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                setState(() => _q = '');
                              },
                              child: Icon(Icons.close_rounded, size: 16, color: p.ink3),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_q.isEmpty)
              Expanded(child: _hints(p, store))
            else if (results.isEmpty)
              const Expanded(
                child: EmptyState(
                  title: '没有找到相关账单',
                  desc: '试试更换关键词，或按分类名搜索',
                  icon: Icons.search_off_rounded,
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  physics: const BouncingScrollPhysics(),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        '找到 ${results.length} 笔 · 支出合计 ${store.money(total)}',
                        style: TextStyle(fontSize: 12, color: p.ink3, fontWeight: FontWeight.w500),
                      ),
                    ),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: List<Widget>.generate(results.length, (int i) {
                          final Bill b = results[i];
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
                                  padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                                  child: Row(
                                    children: <Widget>[
                                      CatBubble(cat: c, size: 40, iconSize: 19),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              b.note.isEmpty ? c.name : b.note,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: p.ink,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${b.date.year}/${b.date.month}/${b.date.day} ${timeLabel(b.date)} · ${c.name}',
                                              style: TextStyle(fontSize: 11, color: p.ink3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${b.expense ? '-' : '+'}${store.money(b.amount)}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: b.expense ? p.ink : p.income,
                                          letterSpacing: -0.4,
                                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (i != results.length - 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 66),
                                  child: Divider(height: 1, color: p.line, thickness: 1),
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

  Widget _hints(Palette p, AppStore store) {
    final List<CategoryDef> cats = <CategoryDef>[...kExpenseCats.take(8), ...kIncomeCats.take(2)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        Text('按分类浏览', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink2)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: cats.map((CategoryDef c) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _ctrl.text = c.name;
                setState(() => _q = c.name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: p.shadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(c.icon, size: 15, color: c.color),
                    const SizedBox(width: 6),
                    Text(c.name, style: TextStyle(fontSize: 12.5, color: p.ink, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        Text('最近记录', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink2)),
        const SizedBox(height: 12),
        ...store.bills.take(5).map((Bill b) {
          final CategoryDef c = catById(b.catId);
          return Pressable(
            onTap: () {
              _ctrl.text = b.note.isEmpty ? c.name : b.note;
              setState(() => _q = _ctrl.text);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded, size: 15, color: p.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.note.isEmpty ? c.name : b.note,
                      style: TextStyle(fontSize: 13, color: p.ink2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${b.date.month}/${b.date.day}',
                    style: TextStyle(fontSize: 11, color: p.ink3),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
