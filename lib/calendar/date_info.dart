import 'calendar_data.dart';

/// 日期资料：节气与公历节日。
///
/// 节气用寿星公式按年推算后写死成表（2025–2027），比运行时近似更可控；
/// 公历节日为固定日期。农历节日与法定调休需要官方数据，此处不内置，
/// 以免显示错误的「补班 / 放假」信息。
class DateInfo {
  const DateInfo({
    this.term,
    this.festival,
    required this.weekend,
    this.holiday = false,
    this.makeup = false,
  });

  final String? term;
  final String? festival;
  final bool weekend;

  /// 法定放假（含调休）
  final bool holiday;

  /// 补班日
  final bool makeup;

  bool get known => term != null || festival != null || holiday || makeup;

  /// 优先级：补班 > 节气 > 节日；日历角标只显示一个，避免拥挤
  String? get label => makeup ? '班' : (term ?? festival);
}

// 每年 24 个节气，按月份排序（每月两个）
const Map<int, List<String>> _terms = <int, List<String>>{
  2025: <String>[
    '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
    '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
    '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
  ],
  2026: <String>[
    '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
    '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
    '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
  ],
  2027: <String>[
    '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
    '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
    '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
  ],
};

/// 每年每个节气的公历日号（12 个月 × 2 个）
const Map<int, List<int>> _termDays = <int, List<int>>{
  2025: <int>[5, 20, 3, 18, 5, 20, 4, 20, 5, 21, 5, 21, 7, 22, 7, 23, 7, 23, 8, 23, 7, 22, 7, 21],
  2026: <int>[5, 20, 4, 19, 5, 20, 5, 20, 5, 21, 5, 21, 7, 23, 7, 23, 7, 23, 8, 23, 7, 22, 7, 22],
  2027: <int>[5, 20, 4, 19, 6, 21, 5, 20, 6, 21, 6, 21, 7, 23, 8, 23, 8, 23, 8, 23, 7, 22, 7, 22],
};

/// 公历固定节日
const Map<int, String> _festivals = <int, String>{
  101: '元旦',
  214: '情人节',
  308: '妇女节',
  312: '植树节',
  401: '愚人节',
  501: '劳动节',
  504: '青年节',
  601: '儿童节',
  701: '建党节',
  801: '建军节',
  910: '教师节',
  1001: '国庆节',
  1031: '万圣夜',
  1111: '双十一',
  1224: '平安夜',
  1225: '圣诞节',
};

/// 内置节气（按年写死）
String? _builtinTerm(DateTime date) {
  final List<String>? names = _terms[date.year];
  final List<int>? days = _termDays[date.year];
  if (names == null || days == null) return null;
  final int idx = (date.month - 1) * 2;
  if (idx + 1 >= days.length) return null;
  if (days[idx] == date.day) return names[idx];
  if (days[idx + 1] == date.day) return names[idx + 1];
  return null;
}

/// 取某天的日期资料：在线假期/节气优先，其次内置
DateInfo dateInfoOf(DateTime date) {
  final int key = date.month * 100 + date.day;
  final HolidayDay? holiday = CalendarData.instance.holidayOf(date);
  final String? term = CalendarData.instance.termOf(date) ?? _builtinTerm(date);
  final bool weekend =
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  if (holiday != null) {
    return DateInfo(
      term: term,
      festival: holiday.off ? holiday.name : null,
      weekend: weekend || holiday.off,
      holiday: holiday.off,
      makeup: !holiday.off,
    );
  }
  return DateInfo(term: term, festival: _festivals[key], weekend: weekend);
}

/// 该年是否有节气资料（内置或在线）
bool hasTermData(int year) =>
    _terms.containsKey(year) || CalendarData.instance.terms.containsKey(year);

const List<int> supportedTermYears = <int>[2025, 2026, 2027];
