import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  static const String _storeKey = 'whale_ledger_v1';

  final List<Bill> _bills = <Bill>[];
  Map<String, double> _budgets = <String, double>{};

  double monthlyBudget = 12000;
  bool darkMode = false;
  int accentIndex = 0;
  bool reminder = true;
  bool loaded = false;
  String userName = '鲸鱼同学';

  List<Bill> get bills => List<Bill>.unmodifiable(_bills);
  Map<String, double> get budgets => Map<String, double>.unmodifiable(_budgets);

  // ---------------------------------------------------------------- 持久化

  Future<void> load() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final String? raw = sp.getString(_storeKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
        final List<dynamic> list = (map['bills'] as List<dynamic>?) ?? <dynamic>[];
        _bills
          ..clear()
          ..addAll(list.map((dynamic e) => Bill.fromJson(e as Map<String, dynamic>)));
        monthlyBudget = (map['monthlyBudget'] as num?)?.toDouble() ?? 12000;
        darkMode = (map['dark'] as bool?) ?? false;
        accentIndex = (map['accent'] as int?) ?? 0;
        reminder = (map['reminder'] as bool?) ?? true;
        userName = (map['user'] as String?) ?? '鲸鱼同学';
        final Map<String, dynamic> b = (map['budgets'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        _budgets = b.map((String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()));
        if (_budgets.isEmpty) _budgets = defaultBudgets();
      } else {
        _bills.addAll(buildSeedBills());
        _budgets = defaultBudgets();
        await _persist();
      }
    } catch (e) {
      if (_bills.isEmpty) _bills.addAll(buildSeedBills());
      if (_budgets.isEmpty) _budgets = defaultBudgets();
    }
    _sort();
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setString(
        _storeKey,
        jsonEncode(<String, dynamic>{
          'bills': _bills.map((Bill b) => b.toJson()).toList(),
          'monthlyBudget': monthlyBudget,
          'dark': darkMode,
          'accent': accentIndex,
          'reminder': reminder,
          'user': userName,
          'budgets': _budgets,
        }),
      );
    } catch (_) {}
  }

  void _sort() => _bills.sort((Bill a, Bill b) => b.date.compareTo(a.date));

  // ---------------------------------------------------------------- 增删改

  void addBill(Bill b) {
    _bills.add(b);
    _sort();
    notifyListeners();
    _persist();
  }

  Bill? removeBill(String id) {
    final int i = _bills.indexWhere((Bill b) => b.id == id);
    if (i < 0) return null;
    final Bill removed = _bills.removeAt(i);
    notifyListeners();
    _persist();
    return removed;
  }

  void setMonthlyBudget(double v) {
    monthlyBudget = v;
    notifyListeners();
    _persist();
  }

  void setCategoryBudget(String catId, double v) {
    _budgets[catId] = v;
    notifyListeners();
    _persist();
  }

  void setDark(bool v) {
    darkMode = v;
    notifyListeners();
    _persist();
  }

  void setAccent(int i) {
    accentIndex = i;
    notifyListeners();
    _persist();
  }

  void setReminder(bool v) {
    reminder = v;
    notifyListeners();
    _persist();
  }

  void setName(String v) {
    userName = v;
    notifyListeners();
    _persist();
  }

  void clearAll() {
    _bills.clear();
    notifyListeners();
    _persist();
  }

  void restoreDemo() {
    _bills
      ..clear()
      ..addAll(buildSeedBills());
    _sort();
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------- 统计

  static List<Bill> inMonth(List<Bill> all, DateTime m) {
    return all
        .where((Bill b) => b.date.year == m.year && b.date.month == m.month)
        .toList();
  }

  static double total(List<Bill> list, {required bool expense}) {
    double s = 0;
    for (final Bill b in list) {
      if (b.expense == expense) s += b.amount;
    }
    return s;
  }

  static Map<String, double> byCategory(List<Bill> list, {required bool expense}) {
    final Map<String, double> m = <String, double>{};
    for (final Bill b in list) {
      if (b.expense != expense) continue;
      m[b.catId] = (m[b.catId] ?? 0) + b.amount;
    }
    return m;
  }

  static List<DayGroup> groupByDay(List<Bill> list) {
    final Map<String, List<Bill>> map = <String, List<Bill>>{};
    for (final Bill b in list) {
      final String k = '${b.date.year}-${b.date.month}-${b.date.day}';
      map.putIfAbsent(k, () => <Bill>[]).add(b);
    }
    final List<DayGroup> groups = map.entries.map((MapEntry<String, List<Bill>> e) {
      final List<Bill> items = e.value..sort((Bill a, Bill b) => b.date.compareTo(a.date));
      return DayGroup(
        DateTime(items.first.date.year, items.first.date.month, items.first.date.day),
        items,
        total(items, expense: true),
        total(items, expense: false),
      );
    }).toList();
    groups.sort((DayGroup a, DayGroup b) => b.day.compareTo(a.day));
    return groups;
  }

  /// 最近 n 个月的支出合计（从旧到新）
  List<double> monthlyTrend({required bool expense, int n = 6, DateTime? end}) {
    final DateTime now = end ?? DateTime.now();
    final List<double> out = <double>[];
    for (int i = n - 1; i >= 0; i--) {
      final DateTime m = DateTime(now.year, now.month - i, 1);
      out.add(total(inMonth(_bills, m), expense: expense));
    }
    return out;
  }

  double monthExpense(DateTime m) => total(inMonth(_bills, m), expense: true);
  double monthIncome(DateTime m) => total(inMonth(_bills, m), expense: false);

  int get totalCount => _bills.length;

  int get activeDays {
    final Set<String> set = <String>{};
    for (final Bill b in _bills) {
      set.add('${b.date.year}-${b.date.month}-${b.date.day}');
    }
    return set.length;
  }

  String exportCsv() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('日期,类型,分类,金额,备注');
    final List<Bill> sorted = List<Bill>.from(_bills)..sort((Bill a, Bill b) => a.date.compareTo(b.date));
    for (final Bill b in sorted) {
      final String d = '${b.date.year}-${_two(b.date.month)}-${_two(b.date.day)} ${_two(b.date.hour)}:${_two(b.date.minute)}';
      sb.writeln('$d,${b.expense ? '支出' : '收入'},${catById(b.catId).name},${b.amount.toStringAsFixed(2)},${b.note}');
    }
    return sb.toString();
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';
}
