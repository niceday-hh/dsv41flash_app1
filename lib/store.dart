import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';
import 'models.dart';
import 'voice/note_history.dart';
import 'platform/reminder.dart';
import 'persist/file_store.dart';

// ---------------------------------------------------------------- isolate 编解码
// 顶层函数才能在 compute 中执行；账本超过 200 条时把 JSON 编解码丢到后台 isolate，
// 避免大账本保存/启动时卡住 UI 线程。
String _encodeLedger(Map<String, dynamic> data) => jsonEncode(data);

Map<String, dynamic> _decodeLedger(String raw) => jsonDecode(raw) as Map<String, dynamic>;

/// 超过该条数启用 isolate，小账本直接同步处理（省掉 isolate 启动开销）
const int _isolateThreshold = 200;

class AppStore extends ChangeNotifier {
  static const String _legacyKey = 'whale_ledger_v1';

  final List<Bill> _bills = <Bill>[];
  Map<String, double> _budgets = <String, double>{};

  // 保存队列：多次改动合并成一次落盘
  bool _saveRequested = false;
  Future<void>? _saving;

  // 启动竞态保护：恢复磁盘数据期间用户已经做过的编辑不能被覆盖
  bool _restoring = true;
  int _editGeneration = 0;
  final Set<String> _touchedPrefs = <String>{};

  /// 等待所有未完成的落盘（退出前调用）
  Future<void> flushPersistence() async {
    while (_saving != null) {
      await _saving;
    }
  }

  double monthlyBudget = 12000;
  bool darkMode = false;
  int accentIndex = 0;
  bool reminder = true;
  int reminderHour = 21;
  int reminderMinute = 30;
  bool loaded = false;
  bool hideAmounts = false;
  bool keepVoiceModel = true;
  int voiceRetentionSeconds = 15;
  /// 记一笔面板里快捷备注的条数（4–24）
  int noteLimit = 8;
  String userName = '鲸鱼同学';

  Future<List<NoteHint>>? _voiceHistory;
  Future<List<NoteHint>> loadVoiceHistory() => _voiceHistory ??= _bills.length >= 200
      ? compute(voiceHistory, List<Bill>.of(_bills), debugLabel: 'voice-history')
      : Future.value(voiceHistory(_bills));

  List<Bill> get bills => List<Bill>.unmodifiable(_bills);
  Map<String, double> get budgets => Map<String, double>.unmodifiable(_budgets);

  // ---------------------------------------------------------------- 持久化

  Future<void> load() async {
    final int generation = _editGeneration;
    try {
      String? raw = await readLedger();
      // 从旧版 SharedPreferences 平滑迁移到文件存储
      if (raw == null || raw.isEmpty) raw = await _readLegacy();
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> map = raw.length >= 65536
            ? await compute(_decodeLedger, raw, debugLabel: 'decode-ledger')
            : _decodeLedger(raw);
        final List<dynamic> list = (map['bills'] as List<dynamic>?) ?? <dynamic>[];
        final List<Bill> parsed = list
            .map((dynamic e) => Bill.fromJson(e as Map<String, dynamic>))
            .toList();

        final bool userEditedWhileLoading = _editGeneration != generation;
        if (!userEditedWhileLoading) {
          _bills
            ..clear()
            ..addAll(parsed);
        }
        _applyPrefs(map, skipTouched: userEditedWhileLoading);
        if (_budgets.isEmpty) _budgets = defaultBudgets();
      } else {
        _bills.addAll(buildSeedBills());
        _budgets = defaultBudgets();
      }
    } catch (e) {
      if (_bills.isEmpty) _bills.addAll(buildSeedBills());
      if (_budgets.isEmpty) _budgets = defaultBudgets();
    }
    _restoring = false;
    _touchedPrefs.clear();
    _voiceHistory = null;
    _sort();
    loaded = true;
    notifyListeners();
    // 首次启动或迁移后立即落盘，保证下次能从文件读回
    _persist();
  }

  /// 应用偏好字段；skipTouched 为 true 时跳过用户在恢复期间改过的项
  void _applyPrefs(Map<String, dynamic> map, {required bool skipTouched}) {
    bool allow(String key) => !skipTouched || !_touchedPrefs.contains(key);
    if (allow('monthlyBudget')) {
      monthlyBudget = (map['monthlyBudget'] as num?)?.toDouble() ?? monthlyBudget;
    }
    if (allow('dark')) darkMode = (map['dark'] as bool?) ?? darkMode;
    if (allow('accent')) accentIndex = (map['accent'] as int?) ?? accentIndex;
    if (allow('reminder')) reminder = (map['reminder'] as bool?) ?? reminder;
    if (allow('reminderTime')) {
      reminderHour = ((map['reminderHour'] as num?)?.toInt() ?? reminderHour).clamp(0, 23);
      reminderMinute = ((map['reminderMinute'] as num?)?.toInt() ?? reminderMinute).clamp(0, 59);
    }
    if (allow('hide')) hideAmounts = (map['hide'] as bool?) ?? hideAmounts;
    if (allow('user')) userName = (map['user'] as String?) ?? userName;
    if (allow('keepVoice')) {
      keepVoiceModel = (map['keepVoice'] as bool?) ?? keepVoiceModel;
    }
    if (allow('voiceRetention')) {
      voiceRetentionSeconds =
          ((map['voiceRetention'] as num?)?.toInt() ?? voiceRetentionSeconds).clamp(5, 30);
    }
    if (allow('noteLimit')) {
      noteLimit = ((map['noteLimit'] as num?)?.toInt() ?? noteLimit).clamp(4, 24);
    }
    if (allow('budgets')) {
      final Map<String, dynamic> b =
          (map['budgets'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (b.isNotEmpty) {
        _budgets = b.map(
          (String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()),
        );
      }
    }
  }

  /// 旧版本使用 shared_preferences 的单个 key，这里读一次用于迁移
  static Future<String?> _readLegacy() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      return sp.getString(_legacyKey);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _snapshot() => <String, dynamic>{
        'bills': _bills.map((Bill b) => b.toJson()).toList(),
        'monthlyBudget': monthlyBudget,
        'dark': darkMode,
        'accent': accentIndex,
        'reminder': reminder,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'hide': hideAmounts,
        'user': userName,
        'keepVoice': keepVoiceModel,
        'voiceRetention': voiceRetentionSeconds,
        'noteLimit': noteLimit,
        'budgets': _budgets,
        'version': 2,
      };

  void _persist() {
    _saveRequested = true;
    _startSaving();
  }

  void _startSaving() {
    if (_saving != null) return;
    _saving = _drainSaves().whenComplete(() {
      _saving = null;
      if (_saveRequested) _startSaving();
    });
  }

  Future<void> _drainSaves() async {
    while (_saveRequested) {
      _saveRequested = false;
      final Map<String, dynamic> snap = _snapshot();
      try {
        final String payload = _bills.length >= _isolateThreshold
            ? await compute(_encodeLedger, snap, debugLabel: 'encode-ledger')
            : _encodeLedger(snap);
        await writeLedger(payload);
        if (_bills.isNotEmpty) _clearLegacy();
      } catch (_) {
        // 落盘失败不影响内存账本
      }
    }
  }

  static Future<void> _clearLegacy() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.remove(_legacyKey);
    } catch (_) {}
  }

  void _touch(String pref) {
    if (pref == 'bills') _voiceHistory = null;
    if (_restoring) _touchedPrefs.add(pref);
    _editGeneration++;
  }

  void _sort() => _bills.sort((Bill a, Bill b) => b.date.compareTo(a.date));

  // ---------------------------------------------------------------- 增删改

  void addBill(Bill b) {
    _touch('bills');
    _bills.add(b);
    _sort();
    notifyListeners();
    _persist();
  }

  void updateBill(Bill updated) {
    final int i = _bills.indexWhere((Bill b) => b.id == updated.id);
    if (i < 0) return;
    _touch('bills');
    _bills[i] = updated;
    _sort();
    notifyListeners();
    _persist();
  }

  void setHideAmounts(bool v) {
    _touch('hide');
    hideAmounts = v;
    notifyListeners();
    _persist();
  }

  void setNoteLimit(int v) {
    _touch('noteLimit');
    noteLimit = v.clamp(4, 24);
    notifyListeners();
    _persist();
  }

  /// 最近用过的分类（按账单时间倒序），用于「改分类」弹层的快捷入口
  List<String> recentCatIds({required bool expense, int limit = 6}) {
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final Bill b in _bills) {
      if (b.expense != expense) continue;
      if (!seen.add(b.catId)) continue;
      out.add(b.catId);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// 统一金额展示（支持隐藏）
  String money(num v, {bool signed = false, bool trimZero = false}) {
    if (hideAmounts) return '••••';
    final String body = _fmtMoney(v, trimZero: trimZero);
    return signed ? '${v >= 0 ? '+' : '-'}¥$body' : '¥$body';
  }

  /// 某分类下最近使用过的备注，用于快捷选择
  List<String> notesForCategory(String catId, {bool expense = true, int? limit}) {
    final int max = (limit ?? noteLimit).clamp(1, 24);
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final Bill b in _bills) {
      if (b.catId != catId || b.expense != expense) continue;
      final String n = b.note.trim();
      if (n.isEmpty || !seen.add(n)) continue;
      out.add(n);
      if (out.length >= max) break;
    }
    return out;
  }

  /// 备注词云数据：按使用次数排序（同分类优先，其次全部分类）
  List<NoteCloudItem> noteCloud(String catId, {bool expense = true, int limit = 14}) {
    final Map<String, int> same = <String, int>{};
    final Map<String, int> other = <String, int>{};
    // 每条备注最常出现的分类，用于词云上色
    final Map<String, Map<String, int>> catHits = <String, Map<String, int>>{};
    for (final Bill b in _bills) {
      if (b.expense != expense) continue;
      final String n = b.note.trim();
      if (n.isEmpty || n.length > 12) continue;
      final Map<String, int> target = b.catId == catId ? same : other;
      target[n] = (target[n] ?? 0) + 1;
      catHits.putIfAbsent(n, () => <String, int>{});
      catHits[n]![b.catId] = (catHits[n]![b.catId] ?? 0) + 1;
    }
    String topCat(String note) {
      final Map<String, int> hits = catHits[note] ?? <String, int>{};
      if (hits.isEmpty) return catId;
      final List<MapEntry<String, int>> e = hits.entries.toList()
        ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
      return e.first.key;
    }

    final List<MapEntry<String, int>> list = same.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    final List<MapEntry<String, int>> rest = other.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    list.addAll(rest);
    return list
        .take(limit)
        .map((MapEntry<String, int> e) => NoteCloudItem(e.key, e.value, topCat(e.key)))
        .toList();
  }

  /// 备注统计：次数、最近使用时间、关联分类（用于备注选择器排序与筛选）
  List<NoteStat> noteStats({bool expense = true}) {
    final Map<String, NoteStat> map = <String, NoteStat>{};
    for (final Bill b in _bills) {
      if (b.expense != expense) continue;
      final String n = b.note.trim();
      if (n.isEmpty) continue;
      final NoteStat st = map.putIfAbsent(n, () => NoteStat(n, b.date));
      st.count++;
      st.cats.add(b.catId);
      if (b.date.isAfter(st.latest)) st.latest = b.date;
    }
    return map.values.toList();
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
    _touch('bills');
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
    _touch('bills');
    final Bill removed = _bills.removeAt(i);
    notifyListeners();
    _persist();
    return removed;
  }

  void setMonthlyBudget(double v) {
    _touch('monthlyBudget');
    monthlyBudget = v;
    notifyListeners();
    _persist();
  }

  void setCategoryBudget(String catId, double v) {
    _touch('budgets');
    _budgets[catId] = v;
    notifyListeners();
    _persist();
  }

  void setDark(bool v) {
    _touch('dark');
    darkMode = v;
    notifyListeners();
    _persist();
  }

  void setAccent(int i) {
    _touch('accent');
    accentIndex = i;
    notifyListeners();
    _persist();
  }

  void setReminderTime(int hour, int minute) {
    _touch('reminderTime');
    reminderHour = hour.clamp(0, 23);
    reminderMinute = minute.clamp(0, 59);
    notifyListeners();
    _persist();
    if (reminder) {
      // 时间改了，把系统闹钟重新登记到新时刻
      ReminderService.schedule(reminderHour, reminderMinute);
    }
  }

  void setReminder(bool v) {
    _touch('reminder');
    reminder = v;
    notifyListeners();
    _persist();
    if (v) {
      ReminderService.schedule(reminderHour, reminderMinute);
    } else {
      ReminderService.cancel();
    }
  }

  /// 启动时补登记每日提醒，保证升级或系统清理后闹钟仍在
  void restoreReminder() {
    if (reminder) ReminderService.restore();
  }

  void setKeepVoiceModel(bool v) {
    _touch('keepVoice');
    keepVoiceModel = v;
    notifyListeners();
    _persist();
  }

  void setVoiceRetention(int seconds) {
    _touch('voiceRetention');
    voiceRetentionSeconds = seconds.clamp(5, 30);
    notifyListeners();
    _persist();
  }

  void setName(String v) {
    _touch('user');
    userName = v;
    notifyListeners();
    _persist();
  }

  void clearAll() {
    _touch('bills');
    _bills.clear();
    notifyListeners();
    _persist();
  }

  void restoreDemo() {
    _touch('bills');
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

/// 备注统计项
class NoteStat {
  NoteStat(this.text, this.latest);
  final String text;

  /// 由 noteStats 累加得到，初始为 0（避免首条记录被算成 2 次）
  int count = 0;
  DateTime latest;
  final Set<String> cats = <String>{};
}

/// 词云条目：文本、使用次数、最常出现的分类（用于上色）
class NoteCloudItem {
  const NoteCloudItem(this.text, this.count, this.catId);
  final String text;
  final int count;
  final String catId;
}

