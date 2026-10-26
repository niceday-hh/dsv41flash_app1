import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../persist/file_store.dart';
import 'net_fetch.dart';

/// 某一天的法定假期信息
class HolidayDay {
  const HolidayDay(this.name, this.off);

  /// 假期名称，如「国庆节」「春节」
  final String name;

  /// true = 放假（含调休），false = 补班
  final bool off;
}

const String _holidayUrl = 'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master';
const String _termUrl = 'https://www.hko.gov.hk/tc/gts/time/calendar/text/files';

/// 内置资料覆盖的年份（节气与固定节日）
const List<int> builtinYears = <int>[2025, 2026, 2027];

/// 解析 holiday-cn 的年度 JSON，校验来源、日期与重复项
Map<int, HolidayDay> parseHolidayJson(String raw, int year) {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) throw const FormatException('结构不正确');
  if (decoded['year'] != year) throw const FormatException('年份不匹配');
  final List<dynamic> papers = (decoded['papers'] as List<dynamic>?) ?? <dynamic>[];
  if (papers.isEmpty) throw const FormatException('缺少公告来源');
  for (final dynamic p in papers) {
    final Uri? u = Uri.tryParse(p.toString());
    if (u == null || u.scheme != 'https' || !(u.host == 'gov.cn' || u.host.endsWith('.gov.cn'))) {
      throw const FormatException('公告来源不可信');
    }
  }
  final List<dynamic> days = (decoded['days'] as List<dynamic>?) ?? <dynamic>[];
  if (days.isEmpty || days.length > 366) throw const FormatException('暂无有效日期');
  final Map<int, HolidayDay> out = <int, HolidayDay>{};
  for (final dynamic row in days) {
    if (row is! Map<String, dynamic>) throw const FormatException('日期字段');
    final String date = (row['date'] ?? '').toString();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) throw const FormatException('日期格式');
    final DateTime d = DateTime.parse(date);
    if (d.year != year) throw const FormatException('年份越界');
    final String name = (row['name'] ?? '').toString().trim();
    if (name.isEmpty || name.length > 40) throw const FormatException('假期名称');
    if (row['isOffDay'] is! bool) throw const FormatException('缺少 isOffDay');
    final int key = d.month * 100 + d.day;
    if (out.containsKey(key)) throw const FormatException('日期重复');
    out[key] = HolidayDay(name, row['isOffDay'] as bool);
  }
  return out;
}

const List<String> _termNames = <String>[
  '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
  '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
  '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
];

String _simplifyTerm(String s) => s
    .replaceAll('驚蟄', '惊蛰')
    .replaceAll('穀雨', '谷雨')
    .replaceAll('小滿', '小满')
    .replaceAll('芒種', '芒种')
    .replaceAll('處暑', '处暑');

/// 解析香港天文台的节气文本，要求 24 个且不重复
Map<int, String> parseTermText(String raw, int year) {
  final Map<int, String> out = <int, String>{};
  final Set<String> names = <String>{};
  for (final String line in const LineSplitter().convert(raw)) {
    final RegExpMatch? m = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日\s+\S+\s+星期\S\s+(\S+)\s*$')
        .firstMatch(line.trim());
    if (m == null) continue;
    final int y = int.parse(m[1]!);
    final int month = int.parse(m[2]!);
    final int day = int.parse(m[3]!);
    final String term = _simplifyTerm(m[4]!);
    if (y != year) continue;
    final DateTime d = DateTime(y, month, day);
    if (d.month != month || d.day != day) continue;
    if (!_termNames.contains(term)) continue;
    if (!names.add(term)) throw const FormatException('节气重复');
    out[month * 100 + day] = term;
  }
  if (out.length != 24) throw const FormatException('节气不完整');
  return out;
}

/// 日历资料仓库：在线假期 / 节气 + 本地缓存 + 24 小时节流自动检查
class CalendarData extends ChangeNotifier {
  CalendarData._();

  static final CalendarData instance = CalendarData._();

  final Map<int, Map<int, HolidayDay>> holidays = <int, Map<int, HolidayDay>>{};
  final Map<int, Map<int, String>> terms = <int, Map<int, String>>{};
  final Map<int, List<String>> papers = <int, List<String>>{};
  final Map<int, DateTime> checkedAt = <int, DateTime>{};
  final Map<int, String> messages = <int, String>{};

  bool automatic = true;
  bool busy = false;
  bool loaded = false;
  String notice = '';

  bool get online => canFetch;

  HolidayDay? holidayOf(DateTime d) => holidays[d.year]?[d.month * 100 + d.day];

  String? termOf(DateTime d) => terms[d.year]?[d.month * 100 + d.day];

  List<String> papersOf(int year) => papers[year] ?? const <String>[];

  /// 有资料的年份：内置 + 已下载
  List<int> get years {
    final Set<int> all = <int>{...builtinYears, ...holidays.keys, ...terms.keys};
    final List<int> list = all.toList()..sort();
    return list;
  }

  /// 读取本地缓存
  Future<void> load() async {
    if (loaded) return;
    loaded = true;
    try {
      final String? raw = await readCalendar();
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
        automatic = data['automatic'] != false;
        final Map<String, dynamic> hs =
            (data['holidays'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        hs.forEach((String y, dynamic v) {
          final int? year = int.tryParse(y);
          if (year == null || v is! Map) return;
          final Map<int, HolidayDay> parsed = <int, HolidayDay>{};
          v.forEach((dynamic k, dynamic val) {
            final int? md = int.tryParse(k.toString());
            if (md == null || val is! Map) return;
            final String name = (val['n'] ?? '').toString();
            final bool off = val['o'] == true;
            if (name.isNotEmpty) parsed[md] = HolidayDay(name, off);
          });
          if (parsed.isNotEmpty) holidays[year] = parsed;
        });
        final Map<String, dynamic> ts =
            (data['terms'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        ts.forEach((String y, dynamic v) {
          final int? year = int.tryParse(y);
          if (year == null || v is! Map) return;
          final Map<int, String> parsed = <int, String>{};
          v.forEach((dynamic k, dynamic val) {
            final int? md = int.tryParse(k.toString());
            if (md != null) parsed[md] = val.toString();
          });
          if (parsed.isNotEmpty) terms[year] = parsed;
        });
        final Map<String, dynamic> ps =
            (data['papers'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        ps.forEach((String y, dynamic v) {
          final int? year = int.tryParse(y);
          if (year != null && v is List) {
            papers[year] = v.map((dynamic e) => e.toString()).toList();
          }
        });
        final Map<String, dynamic> cs =
            (data['checkedAt'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        cs.forEach((String y, dynamic v) {
          final int? year = int.tryParse(y);
          final DateTime? d = DateTime.tryParse(v.toString());
          if (year != null && d != null) checkedAt[year] = d;
        });
        final Map<String, dynamic> ms =
            (data['messages'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        ms.forEach((String y, dynamic v) {
          final int? year = int.tryParse(y);
          if (year != null) messages[year] = v.toString();
        });
      }
    } catch (_) {
      notice = '本地日历缓存读取失败，继续使用内置资料';
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await writeCalendar(jsonEncode(<String, dynamic>{
        'automatic': automatic,
        'holidays': holidays.map((int y, Map<int, HolidayDay> v) => MapEntry<String, dynamic>(
            '$y',
            v.map((int md, HolidayDay d) =>
                MapEntry<String, dynamic>('$md', <String, dynamic>{'n': d.name, 'o': d.off})))),
        'terms': terms.map((int y, Map<int, String> v) =>
            MapEntry<String, dynamic>('$y', v.map((int md, String n) => MapEntry<String, String>('$md', n)))),
        'papers': papers.map((int y, List<String> v) => MapEntry<String, dynamic>('$y', v)),
        'checkedAt': checkedAt.map((int y, DateTime d) =>
            MapEntry<String, String>('$y', d.toIso8601String())),
        'messages': messages.map((int y, String m) => MapEntry<String, String>('$y', m)),
      }));
      notice = '';
    } catch (_) {
      notice = '缓存写入失败，本次资料仅在当前运行中生效';
    }
  }

  Future<void> setAutomatic(bool value) async {
    await load();
    automatic = value;
    await _save();
    notifyListeners();
    if (value) await autoCheck();
  }

  /// 启动或回到前台时调用：每个年份 24 小时内最多检查一次
  Future<void> autoCheck() async {
    await load();
    if (!automatic || busy || !canFetch) return;
    final DateTime now = DateTime.now();
    for (final int year in <int>[now.year, now.year + 1]) {
      if (!automatic) return;
      final DateTime? last = checkedAt[year];
      final bool due = last == null ||
          now.difference(last) >= const Duration(hours: 24) ||
          now.isBefore(last);
      if (due) await check(year);
    }
  }

  /// 手动/自动检查某一年，返回逐项结果
  Future<List<String>> check(int year) async {
    await load();
    final List<String> results = <String>[];
    if (busy) return results;
    if (!canFetch) {
      results.add('当前平台不支持联网更新');
      return results;
    }
    if (year < 2020 || year > DateTime.now().year + 2) {
      results.add('$year 年超出可更新范围');
      return results;
    }
    busy = true;
    notifyListeners();
    try {
      final String? holidayRaw = await fetchText('$_holidayUrl/$year.json');
      if (holidayRaw == null) {
        results.add('假期：网络不可用或来源暂无该年数据');
      } else {
        try {
          final Map<int, HolidayDay> parsed = parseHolidayJson(holidayRaw, year);
          holidays[year] = parsed;
          final dynamic decoded = jsonDecode(holidayRaw);
          if (decoded is Map<String, dynamic> && decoded['papers'] is List) {
            papers[year] = (decoded['papers'] as List<dynamic>)
                .map((dynamic e) => e.toString())
                .toList();
          }
          final int off = parsed.values.where((HolidayDay d) => d.off).length;
          results.add('假期：已更新 ${parsed.length} 天（放假 $off 天，补班 ${parsed.length - off} 天）');
        } on FormatException {
          results.add('假期：数据校验未通过，保留原有资料');
        } catch (_) {
          results.add('假期：数据格式异常，保留原有资料');
        }
      }

      final String? termRaw = await fetchText('$_termUrl/T${year}c.txt');
      if (termRaw == null) {
        results.add('节气：网络不可用或来源暂无该年数据');
      } else {
        try {
          final Map<int, String> parsed = parseTermText(termRaw, year);
          terms[year] = parsed;
          results.add('节气：已更新 ${parsed.length} 个');
        } on FormatException catch (e) {
          results.add('节气：${e.message}，保留原有资料');
        } catch (_) {
          results.add('节气：数据格式异常，保留原有资料');
        }
      }
      checkedAt[year] = DateTime.now();
      messages[year] = results.join('\n');
      await _save();
    } finally {
      busy = false;
      notifyListeners();
    }
    return results;
  }
}
