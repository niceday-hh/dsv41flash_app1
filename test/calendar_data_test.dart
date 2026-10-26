import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/calendar/calendar_data.dart';

void main() {
  test('假期 JSON 正常解析', () {
    const String raw = '{"year":2026,"papers":["https://www.gov.cn/zhengce/a.htm"],'
        '"days":[{"name":"元旦","date":"2026-01-01","isOffDay":true},'
        '{"name":"春节","date":"2026-02-15","isOffDay":false}]}';
    final Map<int, HolidayDay> map = parseHolidayJson(raw, 2026);
    expect(map.length, 2);
    expect(map[101]!.name, '元旦');
    expect(map[101]!.off, isTrue);
    expect(map[215]!.off, isFalse);
  });

  test('假期 JSON 拒绝非官方来源', () {
    const String raw = '{"year":2026,"papers":["https://example.com/a.htm"],'
        '"days":[{"name":"元旦","date":"2026-01-01","isOffDay":true}]}';
    expect(() => parseHolidayJson(raw, 2026), throwsFormatException);
  });

  test('假期 JSON 拒绝年份不符与重复日期', () {
    const String wrongYear = '{"year":2025,"papers":["https://www.gov.cn/a.htm"],'
        '"days":[{"name":"元旦","date":"2026-01-01","isOffDay":true}]}';
    expect(() => parseHolidayJson(wrongYear, 2026), throwsFormatException);
    const String dup = '{"year":2026,"papers":["https://www.gov.cn/a.htm"],'
        '"days":[{"name":"元旦","date":"2026-01-01","isOffDay":true},'
        '{"name":"元旦","date":"2026-01-01","isOffDay":true}]}';
    expect(() => parseHolidayJson(dup, 2026), throwsFormatException);
  });

  test('节气文本解析 24 个', () {
    const List<String> names = <String>[
      '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
      '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
      '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
    ];
    final StringBuffer sb = StringBuffer('2026年1月1日          十三        星期四      \n');
    for (int i = 0; i < 24; i++) {
      final int month = i ~/ 2 + 1;
      final int day = i % 2 == 0 ? 5 : 20;
      sb.writeln('2026年$month月$day日          初一        星期一      ${names[i]}    ');
    }
    final Map<int, String> map = parseTermText(sb.toString(), 2026);
    expect(map.length, 24);
    expect(map[105], '小寒');
    expect(map[120], '大寒');
    expect(map[1220], '冬至');
  });

  test('节气不足 24 个抛错', () {
    expect(() => parseTermText('2026年1月5日          初一        星期一      小寒    ', 2026),
        throwsFormatException);
  });
}
