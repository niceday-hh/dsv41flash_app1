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
  bool hideAmounts = false;
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
        hideAmounts = (map['hide'] as bool?) ?? false;
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
          'hide': hideAmounts,
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

  void updateBill(Bill updated) {
    final int i = _bills.indexWhere((Bill b) => b.id == updated.id);
    if (i < 0) return;
    _bills[i] = updated;
    _sort();
    notifyListeners();
    _persist();
  }

  void setHideAmounts(bool v) {
    hideAmounts = v;
    notifyListeners();
    _persist();
  }

  /// 统一金额展示（支持隐藏）
  String money(num v, {bool signed = false, bool trimZero = false}) {
    if (hideAmounts) return '••••';
    final String body = _fmtMoney(v, trimZero: trimZero);
    return signed ? '${v >= 0 ? '+' : '-'}¥$body' : '¥$body';
  }

  /// 某分类下最近使用过的备注，用于快捷选择
  List<String> notesForCategory(String catId, {bool expense = true, int limit = 8}) {
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final Bill b in _bills) {
      if (b.catId != catId || b.expense != expense) continue;
      final String n = b.note.trim();
      if (n.isEmpty || !seen.add(n)) continue;
      out.add(n);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// 搜索账单：备注 / 分类名 / 金额
  List<Bill> search(String q) {
    final String key = q.trim().toLowerCase();
    if (key.isEmpty) return <Bill>[];
    final List<Bill> out = <Bill>[];
    for (final Bill b in _bills) {
      final CategoryDef c = catById(b.catId);
      if (b.note.toLowerCase().contains(key) ||
          c.name.contains(key) ||
          b.amount.toStringAsFixed(2).contains(key) ||
          b.amount.toStringAsFixed(0) == key) {
        out.add(b);
      }
    }
    return out;
  }

  /// 导入 CSV（表头：日期,类型,分类,金额,备注），返回导入条数
  int importCsv(String raw, {bool replace = false}) {
    String text = raw;
    if (text.startsWith('\ufeff')) text = text.substring(1);
    final int nl = text.indexOf(RegExp(r'[\r\n]'));
    final String firstLine = nl < 0 ? text : text.substring(0, nl);
    final String delimiter = firstLine.contains('\t') ? '\t' : ',';
    final List<List<String>> rows = _parseDelimited(text, delimiter);
    if (rows.isEmpty) return 0;
    final List<String> header = rows.first.map((String e) => e.trim()).toList();
    int idx(String name) => header.indexOf(name);
    final int iDate = idx('日期');
    final int iType = idx('类型');
    final int iCat = idx('分类');
    final int iAmt = idx('金额');
    final int iNote = idx('备注');
    if (<int>[iDate, iType, iCat, iAmt].any((int i) => i < 0)) {
      throw const FormatException('CSV 表头需包含：日期、类型、分类、金额');
    }
    final List<Bill> imported = <Bill>[];
    for (int i = 1; i < rows.length; i++) {
      final List<String> row = rows[i];
      if (row.every((String c) => c.trim().isEmpty)) continue;
      if (row.length <= iAmt) continue;
      final double? amount = double.tryParse(row[iAmt].trim());
      final DateTime? date = _parseCsvDate(row[iDate].trim());
      if (amount == null || amount <= 0 || date == null) continue;
      final String catName = row[iCat].trim();
      final String note = iNote >= 0 && iNote < row.length ? row[iNote].trim() : '';
      imported.add(Bill(
        id: 'csv_${DateTime.now().microsecondsSinceEpoch}_$i',
        catId: catIdByName(catName),
        amount: amount,
        expense: row[iType].trim() != '收入',
        date: date,
        note: note.isEmpty ? catName : note,
      ));
    }
    if (replace) _bills.clear();
    _bills.addAll(imported);
    _sort();
    notifyListeners();
    _persist();
    return imported.length;
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

  static String _fmtMoney(num v, {bool trimZero = false}) {
    final String s = v.abs().toStringAsFixed(2);
    final List<String> parts = s.split('.');
    final String intPart = parts[0];
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    String frac = '.${parts[1]}';
    if (trimZero && frac == '.00') frac = '';
    return '${v < 0 ? '-' : ''}$buf$frac';
  }

  static DateTime? _parseCsvDate(String value) {
    final RegExpMatch? m =
        RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2}))?').firstMatch(value);
    if (m == null) return DateTime.tryParse(value);
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.tryParse(m.group(4) ?? '') ?? 0,
      int.tryParse(m.group(5) ?? '') ?? 0,
    );
  }

  static List<List<String>> _parseDelimited(String text, String delimiter) {
    final List<List<String>> rows = <List<String>>[];
    List<String> row = <String>[];
    StringBuffer field = StringBuffer();
    bool quoted = false;
    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (ch == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && ch == delimiter) {
        row.add(field.toString());
        field = StringBuffer();
      } else if (!quoted && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
