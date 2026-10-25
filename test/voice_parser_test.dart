import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/voice/voice_parser.dart';

void main() {
  test('阿拉伯数字 + 块', () {
    final i = parseVoice('午饭 28 块');
    expect(i.amount, 28);
    expect(i.catId, 'food');
    expect(i.expense, isTrue);
  });

  test('中文数字', () {
    expect(parseVoice('打车二十八块').amount, 28);
    expect(parseVoice('房租两千六百块').amount, 2600);
    expect(parseVoice('买菜一百零五').amount, 105);
    expect(parseVoice('奶茶十五块五').amount, 15.5);
  });

  test('分类识别', () {
    expect(parseVoice('地铁三块').catId, 'traffic');
    expect(parseVoice('奶茶十八块').catId, 'food');
    expect(parseVoice('买衣服三百块').catId, 'shop');
    expect(parseVoice('电影票四十五块').catId, 'fun');
    expect(parseVoice('话费五十块').catId, 'phone');
  });

  test('收入识别', () {
    final i = parseVoice('工资到账 8000');
    expect(i.expense, isFalse);
    expect(i.catId, 'salary');
    expect(i.amount, 8000);
  });

  test('日期识别', () {
    final now = DateTime(2026, 10, 25);
    expect(parseVoice('昨天吃饭三十块', now: now).date.day, 24);
    expect(parseVoice('前天打车二十块', now: now).date.day, 23);
    expect(parseVoice('今天咖啡二十块', now: now).date.day, 25);
  });

  test('无效语句', () {
    expect(parseVoice('你好').valid, isFalse);
  });
}
