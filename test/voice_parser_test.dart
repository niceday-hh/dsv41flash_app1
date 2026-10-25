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

  _robustness();
}

void _robustness() {
  test('全角与千分位', () {
    expect(parseVoice('午饭２８块').amount, 28);
    expect(parseVoice('房租1,280元').amount, 1280);
  });

  test('屏蔽数量与时间点', () {
    expect(parseVoice('买2杯咖啡30块').amount, 30);
    expect(parseVoice('10点半吃饭30块').amount, 30);
    expect(parseVoice('跑了30分钟，打车25块').amount, 25);
  });

  test('否定短语', () {
    final i = parseVoice('不是买衣服，是打车28块');
    expect(i.amount, 28);
    expect(i.catId, 'traffic');
  });

  test('显式备注', () {
    final i = parseVoice('午饭28块，备注牛肉面');
    expect(i.amount, 28);
    expect(i.note.contains('牛肉面'), isTrue);
  });

  test('金额缺失给出警告', () {
    final i = parseVoice('今天中午吃饭');
    expect(i.valid, isFalse);
    expect(i.warnings.any((String w) => w.contains('金额')), isTrue);
  });
}
