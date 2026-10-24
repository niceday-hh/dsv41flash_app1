import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

Future<bool?> showAddBillSheet(BuildContext context, {bool expense = true, String? catId}) {
  final AppStore store = AppScope.storeOf(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.38),
    builder: (BuildContext ctx) => _AddBillSheet(
      store: store,
      initialExpense: expense,
      initialCatId: catId,
    ),
  );
}

class _AddBillSheet extends StatefulWidget {
  final AppStore store;
  final bool initialExpense;
  final String? initialCatId;

  const _AddBillSheet({Key? key, required this.store, required this.initialExpense, this.initialCatId})
      : super(key: key);

  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  late bool _expense;
  String _amount = '';
  String _catId = '';
  late DateTime _date;
  final TextEditingController _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _expense = widget.initialExpense;
    _catId = widget.initialCatId ?? catsFor(_expense).first.id;
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.isEmpty ? '0' : _amount) ?? 0;

  void _press(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == 'del') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
        return;
      }
      if (k == '.') {
        if (_amount.contains('.')) return;
        _amount = _amount.isEmpty ? '0.' : '$_amount.';
        return;
      }
      if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
      if (_amount == '0') _amount = k;
      else if (_amount.replaceAll('.', '').length >= 8) return;
      else _amount += k;
    });
  }

  void _save() {
    if (_value <= 0) {
      HapticFeedback.heavyImpact();
      showToast(context, '请输入金额', icon: Icons.info_rounded);
      return;
    }
    setState(() => _saving = true);
    widget.store.addBill(Bill(
      id: 'bill_${DateTime.now().microsecondsSinceEpoch}',
      catId: _catId,
      amount: double.parse(_value.toStringAsFixed(2)),
      expense: _expense,
      date: DateTime(_date.year, _date.month, _date.day, DateTime.now().hour, DateTime.now().minute),
      note: _noteCtrl.text.trim(),
    ));
    Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final double maxH = MediaQuery.of(context).size.height * 0.92;
    final List<CategoryDef> cats = catsFor(_expense);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 拖拽条
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('记一笔', style: T.h2(p)),
                        const Spacer(),
                        Segmented(
                          labels: const <String>['支出', '收入'],
                          index: _expense ? 0 : 1,
                          compact: true,
                          onChanged: (int i) {
                            setState(() {
                              _expense = i == 0;
                              _catId = catsFor(_expense).first.id;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Pressable(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: p.cardSoft,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(Icons.close_rounded, size: 16, color: p.ink2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 金额
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _expense ? p.expense : p.income,
                          ),
                        ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            transitionBuilder: (Widget child, Animation<double> a) =>
                                FadeTransition(opacity: a, child: child),
                            child: Text(
                              _amount.isEmpty ? '0.00' : _amount,
                              key: ValueKey<String>(_amount),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.6,
                                height: 1.1,
                                color: _amount.isEmpty ? p.ink3 : p.ink,
                                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _expense ? '支出' : '收入',
                            key: ValueKey<bool>(_expense),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _expense ? p.expense : p.income,
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 备注 + 日期
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: p.cardSoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _noteCtrl,
                                style: TextStyle(fontSize: 13, color: p.ink, fontWeight: FontWeight.w500),
                                cursorColor: p.accent,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '写点备注…',
                                  hintStyle: TextStyle(fontSize: 13, color: p.ink3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Pressable(
                          onTap: _pickDate,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: p.cardSoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.calendar_today_rounded, size: 13, color: p.ink2),
                                const SizedBox(width: 6),
                                Text(
                                  dayLabel(_date),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 分类网格
                    SizedBox(
                      height: 262,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.02,
                        ),
                        itemCount: cats.length,
                        itemBuilder: (BuildContext context, int i) {
                          final CategoryDef c = cats[i];
                          final bool on = c.id == _catId;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _catId = c.id);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                color: on ? c.color.withOpacity(0.10) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: on ? c.color.withOpacity(0.45) : Colors.transparent,
                                  width: 1.4,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  AnimatedScale(
                                    scale: on ? 1.08 : 1,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: on ? c.color : c.color.withOpacity(p.dark ? 0.18 : 0.13),
                                        borderRadius: BorderRadius.circular(13),
                                        boxShadow: on
                                            ? <BoxShadow>[
                                                BoxShadow(
                                                  color: c.color.withOpacity(0.35),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(c.icon, size: 19, color: on ? Colors.white : c.color),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                      color: on ? c.color : p.ink2,
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
              ),
            ),
            // 数字键盘
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: p.dark ? const Color(0xFF12141E) : const Color(0xFFF7F7FB),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: <Widget>[
                    _row(<String>['1', '2', '3']),
                    _row(<String>['4', '5', '6']),
                    _row(<String>['7', '8', '9']),
                    _row(<String>['.', '0', 'del']),
                    const SizedBox(height: 8),
                    Pressable(
                      onTap: _save,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: p.gradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: p.accentGlow,
                        ),
                        alignment: Alignment.center,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                '保存 · ¥${_value <= 0 ? '0.00' : _value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    final Palette p = AppScope.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: keys.map((String k) {
          final bool del = k == 'del';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Pressable(
                onTap: () => _press(k),
                scale: 0.92,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: del ? Colors.transparent : p.card,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: del
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(p.dark ? 0.18 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: del
                      ? Icon(Icons.backspace_outlined, size: 19, color: p.ink2)
                      : Text(
                          k,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
