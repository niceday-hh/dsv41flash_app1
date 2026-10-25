import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../voice/asr_engine.dart' as asr;
import '../voice/voice_parser.dart';
import '../voice/voice_sheet.dart';
import 'common.dart';

/// 打开记账 / 编辑账单面板。传入 [bill] 即为编辑模式。
Future<bool?> showBillSheet(BuildContext context,
    {Bill? bill, bool expense = true, String? catId, double? initialAmount, String? initialNote}) {
  final AppStore store = AppScope.storeOf(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.38),
    builder: (BuildContext ctx) => _BillSheet(
      store: store,
      bill: bill,
      initialExpense: bill?.expense ?? expense,
      initialCatId: bill?.catId ?? catId,
      initialAmount: initialAmount,
      initialNote: initialNote,
    ),
  );
}

Future<bool?> showAddBillSheet(BuildContext context, {bool expense = true, String? catId}) =>
    showBillSheet(context, expense: expense, catId: catId);

class _BillSheet extends StatefulWidget {
  final AppStore store;
  final Bill? bill;
  final bool initialExpense;
  final String? initialCatId;
  final double? initialAmount;
  final String? initialNote;

  const _BillSheet({
    Key? key,
    required this.store,
    this.bill,
    required this.initialExpense,
    this.initialCatId,
    this.initialAmount,
    this.initialNote,
  }) : super(key: key);

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  late bool _expense;
  String _expr = '';
  String _catId = '';
  late DateTime _date;
  late TextEditingController _noteCtrl;
  bool _saving = false;
  bool _evaluated = false;

  bool get _editing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final Bill? b = widget.bill;
    _expense = b?.expense ?? widget.initialExpense;
    _catId = b?.catId ?? widget.initialCatId ?? catsFor(_expense).first.id;
    _date = b?.date ?? DateTime.now();
    _noteCtrl = TextEditingController(text: b?.note ?? widget.initialNote ?? '');
    if (b == null && widget.initialAmount != null && widget.initialAmount! > 0) {
      final double v = widget.initialAmount!;
      _expr = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
      _evaluated = true;
    }
    if (b != null) {
      _expr = b.amount == b.amount.roundToDouble()
          ? b.amount.toStringAsFixed(0)
          : b.amount.toStringAsFixed(2);
      _evaluated = true;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 表达式计算

  double get _value => _calc(_expr);

  static double _calc(String src) {
    if (src.isEmpty) return 0;
    double sum = 0;
    double sign = 1;
    final StringBuffer num = StringBuffer();
    for (int i = 0; i < src.length; i++) {
      final String ch = src[i];
      if (ch == '+' || ch == '-') {
        if (num.isNotEmpty) {
          sum += sign * (double.tryParse(num.toString()) ?? 0);
          num.clear();
        }
        sign = ch == '+' ? 1 : -1;
      } else {
        num.write(ch);
      }
    }
    if (num.isNotEmpty) sum += sign * (double.tryParse(num.toString()) ?? 0);
    return sum;
  }

  static bool _isOp(String ch) => ch == '+' || ch == '-';

  void _press(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == 'del') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        _evaluated = false;
        return;
      }
      if (k == 'C') {
        _expr = '';
        _evaluated = false;
        return;
      }
      if (k == '=') {
        final double v = _value;
        _expr = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
        _evaluated = true;
        return;
      }
      if (_evaluated && !_isOp(k)) {
        _expr = '';
        _evaluated = false;
      }
      if (_isOp(k)) {
        if (_expr.isEmpty) return;
        if (_isOp(_expr[_expr.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1) + k;
          return;
        }
        _evaluated = false;
        _expr += k;
        return;
      }
      if (k == '.') {
        final String tail = _expr.split(RegExp(r'[+-]')).last;
        if (tail.contains('.')) return;
        _expr = _expr.isEmpty || _isOp(_expr[_expr.length - 1]) ? '${_expr}0.' : '$_expr.';
        return;
      }
      final String tail = _expr.split(RegExp(r'[+-]')).last;
      if (tail.contains('.') && tail.split('.')[1].length >= 2) return;
      if (tail.replaceAll('.', '').length >= 8) return;
      if (tail == '0') {
        _expr = _expr.substring(0, _expr.length - 1) + k;
        return;
      }
      _expr += k;
    });
  }

  // ------------------------------------------------------------ 保存

  Future<void> _save() async {
    final double v = _value;
    if (v <= 0) {
      HapticFeedback.heavyImpact();
      showToast(context, '请输入金额', icon: Icons.info_rounded);
      return;
    }
    setState(() => _saving = true);
    final String note = _noteCtrl.text.trim();
    final DateTime when = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _editing ? widget.bill!.date.hour : DateTime.now().hour,
      _editing ? widget.bill!.date.minute : DateTime.now().minute,
    );
    if (_editing) {
      widget.store.updateBill(Bill(
        id: widget.bill!.id,
        catId: _catId,
        amount: double.parse(v.toStringAsFixed(2)),
        expense: _expense,
        date: when,
        note: note,
      ));
    } else {
      widget.store.addBill(Bill(
        id: 'bill_${DateTime.now().microsecondsSinceEpoch}',
        catId: _catId,
        amount: double.parse(v.toStringAsFixed(2)),
        expense: _expense,
        date: when,
        note: note,
      ));
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final bool ok = await _confirmDelete(context);
    if (!ok || !mounted) return;
    widget.store.removeBill(widget.bill!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final double maxH = MediaQuery.of(context).size.height * 0.92;
    final List<CategoryDef> cats = catsFor(_expense);
    final bool hasOp = _expr.contains('+') || _expr.contains('-');
    final List<MapEntry<String, int>> cloud = widget.store.noteCloud(_catId, expense: _expense, limit: 8);

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
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
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
                        Text(_editing ? '编辑账单' : '记一笔', style: T.h2(p)),
                        const Spacer(),
                        if (_editing)
                          Pressable(
                            onTap: _delete,
                            child: Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: p.expense.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(Icons.delete_outline_rounded, size: 16, color: p.expense),
                            ),
                          ),
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
                    const SizedBox(height: 12),
                    // 金额 / 表达式
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
                            duration: const Duration(milliseconds: 150),
                            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            child: Text(
                              _expr.isEmpty ? '0.00' : _expr,
                              key: ValueKey<String>(_expr),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _expr.length > 9 ? 32 : 40,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.6,
                                height: 1.1,
                                color: _expr.isEmpty ? p.ink3 : p.ink,
                                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        Pressable(
                          onTap: () async {
                            if (!asr.AsrEngine.supported) {
                              showToast(context, '语音记账目前仅支持 Android 客户端',
                                  icon: Icons.mic_off_rounded);
                              return;
                            }
                            final VoiceIntent? intent = await showVoiceSheet(context);
                            if (intent == null || !mounted) return;
                            setState(() {
                              _expense = intent.expense;
                              _catId = intent.catId;
                              final double v = intent.amount;
                              _expr = v == v.roundToDouble()
                                  ? v.toStringAsFixed(0)
                                  : v.toStringAsFixed(2);
                              _evaluated = true;
                              _date = intent.date;
                              _noteCtrl.text = intent.note;
                              _noteCtrl.selection =
                                  TextSelection.collapsed(offset: intent.note.length);
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.only(left: 8, bottom: 2),
                            decoration: BoxDecoration(
                              gradient: p.gradient,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: p.accentGlow,
                            ),
                            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 19),
                          ),
                        ),
                        if (hasOp)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '= ${fmtMoney(_value)}',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                    if (cloud.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Icon(Icons.cloud_queue_rounded, size: 13, color: p.accent),
                          const SizedBox(width: 5),
                          Text(
                            '常用备注',
                            style: TextStyle(fontSize: 11, color: p.ink3, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '点一下即可填入',
                            style: TextStyle(fontSize: 9.5, color: p.ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 74),
                        child: SingleChildScrollView(
                          child: _NoteCloud(
                        data: cloud,
                        palette: p,
                        selected: _noteCtrl.text,
                        onTap: (String text) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _noteCtrl.text = _noteCtrl.text == text ? '' : text;
                            _noteCtrl.selection =
                                TextSelection.collapsed(offset: _noteCtrl.text.length);
                          });
                        },
                      ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 216,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.32,
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
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: on ? c.color : c.color.withOpacity(p.dark ? 0.18 : 0.13),
                                        borderRadius: BorderRadius.circular(12),
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
                                      child: Icon(c.icon, size: 18, color: on ? Colors.white : c.color),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 10,
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
            // 数字键盘（支持 + − 计算）
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
                    _keyRow(p, <String>['1', '2', '3', 'del']),
                    _keyRow(p, <String>['4', '5', '6', '+']),
                    _keyRow(p, <String>['7', '8', '9', '-']),
                    _keyRow(p, <String>['.', '0', 'C', '=']),
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
                                '${_editing ? '保存修改' : '保存'} · ¥${fmtMoney(_value)}',
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

  Widget _keyRow(Palette p, List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: keys.map((String k) {
          final bool fn = k == 'del' || k == 'C' || k == '=' || k == '+' || k == '-';
          final bool accent = k == '=' || k == '+';
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
                    color: accent ? p.accent.withOpacity(0.10) : (fn ? Colors.transparent : p.card),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: fn
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(p.dark ? 0.18 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: k == 'del'
                      ? Icon(Icons.backspace_outlined, size: 19, color: p.ink2)
                      : Text(
                          k,
                          style: TextStyle(
                            fontSize: k == 'C' || k == '=' ? 18 : 21,
                            fontWeight: FontWeight.w600,
                            color: accent ? p.accent : (fn ? p.ink2 : p.ink),
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

Future<bool> _confirmDelete(BuildContext context) async {
  final Palette p = AppScope.paletteOf(context);
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('删除这笔账单？', style: T.h2(p).copyWith(fontSize: 17)),
      content: Text('删除后无法恢复。', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('取消', style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('删除', style: TextStyle(color: p.expense, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok ?? false;
}


/// 备注词云：字号与颜色深浅随使用次数变化
class _NoteCloud extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final Palette palette;
  final String selected;
  final ValueChanged<String> onTap;

  const _NoteCloud({
    Key? key,
    required this.data,
    required this.palette,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int maxCount = data.fold<int>(1, (int m, MapEntry<String, int> e) => e.value > m ? e.value : m);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: data.map((MapEntry<String, int> e) {
        final double ratio = maxCount <= 1 ? 0.45 : (e.value - 1) / (maxCount - 1);
        final double font = 11 + ratio * 5.5;
        final bool on = selected == e.key;
        final Color base = on ? palette.accent : palette.ink2;
        return GestureDetector(
          onTap: () => onTap(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 9 + ratio * 3, vertical: 4 + ratio * 2),
            decoration: BoxDecoration(
              color: on
                  ? palette.accent.withOpacity(0.14)
                  : palette.accent.withOpacity(0.05 + ratio * 0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: on ? palette.accent.withOpacity(0.45) : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Text(
              e.key,
              style: TextStyle(
                fontSize: font,
                height: 1.1,
                fontWeight: ratio > 0.55 ? FontWeight.w700 : FontWeight.w500,
                color: on ? palette.accent : base.withOpacity(0.62 + ratio * 0.38),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
