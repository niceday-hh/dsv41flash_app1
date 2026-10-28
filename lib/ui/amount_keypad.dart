import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'common.dart';

/// 独立的金额键盘弹层：点账单金额时直接改数，不必进完整编辑页。
Future<double?> showAmountKeypad(
  BuildContext context, {
  double initial = 0,
  bool expense = true,
}) {
  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext ctx) =>
        _AmountKeypad(initial: initial, expense: expense),
  );
}

class _AmountKeypad extends StatefulWidget {
  const _AmountKeypad({Key? key, required this.initial, required this.expense})
      : super(key: key);

  final double initial;
  final bool expense;

  @override
  State<_AmountKeypad> createState() => _AmountKeypadState();
}

class _AmountKeypadState extends State<_AmountKeypad> {
  late String _value;
  bool _replace = true;

  @override
  void initState() {
    super.initState();
    _value = widget.initial <= 0 ? '0' : _trim(widget.initial);
  }

  static String _trim(double v) {
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '⌫') {
        if (_replace) {
          _value = '0';
          _replace = false;
          return;
        }
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
        if (_value.isEmpty) _value = '0';
        return;
      }
      if (key == '.') {
        if (_replace) {
          _value = '0.';
          _replace = false;
          return;
        }
        if (!_value.contains('.')) _value = '$_value.';
        return;
      }
      if (_replace) {
        _value = key;
        _replace = false;
        return;
      }
      final int dot = _value.indexOf('.');
      if (dot >= 0 && _value.length - dot > 2) return;
      if (_value == '0') {
        _value = key;
      } else if (_value.replaceAll('.', '').length < 9) {
        _value += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final Color accent = widget.expense ? p.accent : p.income;
    final double amount = double.tryParse(_value) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: p.line, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Text('修改金额', style: T.h2(p).copyWith(fontSize: 16)),
                const Spacer(),
                Text(
                  widget.expense ? '支出' : '收入',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.cardSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('¥',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.ink2)),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: -0.8,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final List<String> row in <List<String>>[
              <String>['1', '2', '3'],
              <String>['4', '5', '6'],
              <String>['7', '8', '9'],
              <String>['.', '0', '⌫'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: row.map((String k) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Pressable(
                          onTap: () => _press(k),
                          scale: 0.91,
                          holdMs: 90,
                          builder: (bool down) => Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: down
                                  ? (p.dark
                                      ? Colors.white.withOpacity(0.13)
                                      : const Color(0xFFE2E5EF))
                                  : p.cardSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: k == '⌫'
                                ? Icon(Icons.backspace_outlined,
                                    size: 19, color: p.ink2)
                                : Text(
                                    k,
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      color: p.ink,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Pressable(
                onTap: () {
                  if (amount <= 0) return;
                  Navigator.pop(context, amount);
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: p.gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: p.accentGlow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '确定 ${amount > 0 ? '· ¥${_trim(amount)}' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
