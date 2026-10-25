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
    expect(parseVoice('买衣服三百块').catId, 'cloth');
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
  _v151Rules();
}

void _v151Rules() {
  final DateTime now = DateTime(2026, 10, 25, 20, 30);

  test('口语简写与角分', () {
    expect(parseVoice('买菜一百二').amount, 120);
    expect(parseVoice('请客一千五').amount, 1500);
    expect(parseVoice('房租一万二').amount, 12000);
    expect(parseVoice('奶茶三块二毛五').amount, 3.25);
    expect(parseVoice('矿泉水一块五').amount, 1.5);
    expect(parseVoice('二十八点五块').amount, 28.5);
  });

  test('动词后的裸数字与总额优先级', () {
    expect(parseVoice('打车花了 28').amount, 28);
    expect(parseVoice('午饭 18 奶茶 12 一共 30').amount, 30);
    expect(parseVoice('不对，是 45').amount, 45);
  });

  test('多金额提示', () {
    final i = parseVoice('买了 20 又买了 30');
    expect(i.warnings.any((String w) => w.contains('多个金额')), isTrue);
  });

  test('日期表达更全', () {
    expect(parseVoice('三天前理发三十块', now: now).date.day, 22);
    expect(parseVoice('上周五看电影五十块', now: now).date.day, 16);
    expect(parseVoice('10月1号买菜60块', now: now).date.month, 10);
    expect(parseVoice('2026-09-30 打车 20', now: now).date.month, 9);
    expect(parseVoice('明天买菜 30 块', now: now).date.day, 26);
    final vague = parseVoice('上个月吃饭 300', now: now);
    expect(vague.warnings.any((String w) => w.contains('日期不明确')), isTrue);
  });

  test('显式分类与历史备注', () {
    expect(parseVoice('分类是交通 20 块', now: now).catId, 'traffic');
    final hinted = parseVoice('星巴克 32', now: now, history: const <NoteHint>[
      NoteHint('星巴克', 'food', 6),
    ]);
    expect(hinted.catId, 'food');
  });
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
