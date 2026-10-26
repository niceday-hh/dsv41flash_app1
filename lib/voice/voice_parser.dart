import '../data.dart';
import '../models.dart';

/// 语音记账解析结果
class VoiceIntent {
  final double amount;
  final String catId;
  final String note;
  final DateTime date;
  final bool expense;
  final String rawText;
  final List<String> warnings;

  const VoiceIntent({
    required this.amount,
    required this.catId,
    required this.note,
    required this.date,
    this.expense = true,
    this.rawText = '',
    this.warnings = const <String>[],
  });

  bool get valid => amount > 0;

  VoiceIntent copyWith({
    double? amount,
    String? catId,
    String? note,
    DateTime? date,
    bool? expense,
  }) {
    final List<String> w = warnings.where((String s) {
      if (amount != null && s.contains('金额')) return false;
      if (catId != null && (s.contains('分类') || s.contains('用途'))) return false;
      if (date != null && s.contains('日期')) return false;
      return true;
    }).toList();
    if (amount != null && (amount <= 0 || amount > 999999999)) {
      w.add('金额需大于零且不超过九位数字');
    }
    if (catId != null && catId == 'other') w.add('用途不明确，请选择分类');
    return VoiceIntent(
      amount: amount ?? this.amount,
      catId: catId ?? this.catId,
      note: note ?? this.note,
      date: date ?? this.date,
      expense: expense ?? this.expense,
      rawText: rawText,
      warnings: w,
    );
  }
}

/// 历史备注提示：用于按用户自己的说法推荐分类
class NoteHint {
  const NoteHint(this.text, this.catId, this.count);
  final String text;
  final String catId;
  final int count;
}

// ------------------------------------------------------------------ 词典

const Map<String, List<String>> _catWords = <String, List<String>>{
  'food': <String>[
    '吃', '饭', '早餐', '午餐', '晚餐', '午饭', '晚饭', '外卖', '奶茶', '咖啡',
    '水果', '零食', '火锅', '烧烤', '饮料', '面条', '包子', '买菜', '菜', '餐厅',
    '食堂', '聚餐', '夜宵', '早点', '点心', '蛋糕', '汉堡', '披萨', '米饭', '麻辣烫',
  ],
  'traffic': <String>[
    '打车', '地铁', '公交', '高铁', '火车', '机票', '飞机', '油费', '加油', '停车',
    '滴滴', '出租车', '车费', '地铁票', '共享单车', '单车', '过路费',
  ],
  'shop': <String>['购物', '淘宝', '京东', '超市', '商场', '网购', '百货', '买'],
  'fun': <String>['电影', '游戏', '娱乐', '唱歌', '演出', '门票', '剧本杀', '密室', 'KTV'],
  'daily': <String>['日用', '纸巾', '洗衣液', '洗漱', '清洁', '垃圾袋'],
  'veg': <String>['蔬菜', '青菜', '菜市场', '白菜', '土豆', '西红柿'],
  'fruit': <String>['水果', '苹果', '香蕉', '西瓜', '葡萄', '橙子'],
  'snack': <String>['零食', '薯片', '巧克力', '饼干', '辣条'],
  'sport': <String>['健身', '运动', '游泳', '球', '跑步', '瑜伽'],
  'cloth': <String>['衣服', '裤子', '鞋', '帽子', '外套', '内衣'],
  'house': <String>['家居', '收纳', '床单', '窗帘', '锅', '餐具'],
  'child': <String>['孩子', '奶粉', '尿不湿', '幼儿园', '玩具'],
  'elder': <String>['长辈', '爸妈', '父母', '老人'],
  'social': <String>['社交', '聚餐', '请客', '份子'],
  'wine': <String>['烟', '酒', '啤酒', '白酒', '红酒'],
  'digital': <String>['数码', '手机', '电脑', '耳机', '充电器', '键盘'],
  'car': <String>['汽车', '加油', '停车', '保养', '洗车', '油费'],
  'book': <String>['书籍', '书', '小说', '教材'],
  'giftout': <String>['礼金', '随礼', '份子钱'],
  'present': <String>['礼物', '送礼', '生日礼物'],
  'office': <String>['办公', '文具', '打印', '复印', '工位'],
  'repair': <String>['维修', '修理', '换屏', '修手机'],
  'donate': <String>['捐赠', '捐款', '公益'],
  'lottery': <String>['彩票', '刮刮乐', '六合彩'],
  'relative': <String>['亲友', '亲戚', '表哥', '堂姐'],
  'express': <String>['快递', '寄件', '运费'],
  'home': <String>['房租', '水费', '电费', '燃气', '物业', '水电', '装修'],
  'phone': <String>['话费', '流量', '手机费', '宽带费', '充值'],
  'health': <String>['药', '医院', '看病', '体检', '挂号', '医疗', '牙医', '口罩'],
  'study': <String>['学习', '课程', '培训', '考试', '报名费', '学费'],
  'travel': <String>['旅行', '旅游', '酒店', '民宿', '景点', '度假'],
  'pet': <String>['猫粮', '狗粮', '宠物', '猫砂'],
  'beauty': <String>['理发', '美容', '美甲', '按摩', '洗脸', '化妆品', '护肤'],
  'salary': <String>['工资', '薪水', '发工资', '月薪', '薪资'],
  'bonus': <String>['奖金', '年终奖', '提成', '奖励'],
  'invest': <String>['理财', '基金', '股票', '分红', '利息', '收益'],
  'gift': <String>['红包', '礼金', '压岁钱'],
  'reimburse': <String>['报销', '报账'],
  'refund': <String>['退款', '退回', '返还'],
};

const Set<String> _incomeCats = <String>{'salary', 'bonus', 'invest', 'gift', 'reimburse', 'refund'};

const Map<String, int> _digit = <String, int>{
  '零': 0, '〇': 0, '一': 1, '壹': 1, '二': 2, '两': 2, '贰': 2, '三': 3, '叁': 3,
  '四': 4, '肆': 4, '五': 5, '伍': 5, '六': 6, '陆': 6, '七': 7, '柒': 7, '八': 8,
  '捌': 8, '九': 9, '玖': 9,
};

const Map<String, int> _unit = <String, int>{
  '十': 10, '拾': 10, '百': 100, '佰': 100, '千': 1000, '仟': 1000, '万': 10000, '亿': 100000000,
};

/// 中文数字 → 数字："二十八" → 28，"一百零五" → 105，"一百二" → 120（口语简写），
/// "二十八点五" → 28.5。
double? cnNumber(String text) {
  if (text.isEmpty) return null;
  final String normalized = text.replaceAll('点', '.');
  final List<String> parts = normalized.split('.');
  final double? integer = _cnInteger(parts.first);
  if (integer == null) return null;
  if (parts.length == 1) return integer;
  final String frac = parts[1].replaceAllMapped(
      RegExp('[零〇一二两三四五六七八九]'), (Match m) => '${_digit[m[0]]}');
  final double f = double.tryParse('0.$frac') ?? 0;
  return integer + f;
}

double? _cnInteger(String text) {
  if (text.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(text)) return double.tryParse(text);
  double total = 0;
  double section = 0;
  double number = 0;
  bool hasAny = false;
  double lastUnit = 1;
  for (int i = 0; i < text.length; i++) {
    final String ch = text[i];
    if (_digit.containsKey(ch)) {
      number = _digit[ch]!.toDouble();
      hasAny = true;
    } else if (_unit.containsKey(ch)) {
      final int u = _unit[ch]!;
      hasAny = true;
      if (u >= 10000) {
        section = (section + number) * u;
        total += section;
        section = 0;
      } else {
        section += (number == 0 ? 1 : number) * u;
      }
      number = 0;
      lastUnit = u.toDouble();
    } else {
      return null;
    }
  }
  if (!hasAny) return null;
  // 口语简写：一百二 = 120、一千五 = 1500、一万二 = 12000；有「零」时不启用
  final bool shorthand = RegExp(r'[百千万][一二两三四五六七八九]$').hasMatch(text);
  return total + section + (shorthand ? number * lastUnit / 10 : number);
}

// ------------------------------------------------------------------ 文本归一化

/// 全角数字/符号转半角，统一标点
String _normalize(String raw) {
  final StringBuffer sb = StringBuffer();
  for (final int code in raw.runes) {
    if (code >= 0xFF10 && code <= 0xFF19) {
      sb.writeCharCode(code - 0xFEE0); // ０-９
    } else if (code == 0xFF0E) {
      sb.write('.');
    } else if (code == 0xFF0C) {
      sb.write(',');
    } else if (code == 0x3002 || code == 0xFF1F || code == 0xFF01) {
      sb.write(' ');
    } else {
      sb.writeCharCode(code);
    }
  }
  String s = sb.toString();
  // 千分位：1,280 → 1280
  s = s.replaceAllMapped(RegExp(r'(?<=\d),(?=\d{3}(?:\D|$))'), (Match _) => '');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 把"3公里""2杯""30分钟""10点半"等非金额数字遮蔽掉，避免误当金额
String _maskNonMoney(String text) {
  String masked = text;
  void mask(RegExp re) {
    masked = masked.replaceAllMapped(re, (Match m) => ' ' * (m[0]!.length));
  }

  mask(RegExp(
      r'(?:[0-9]{1,2}|[一二两三四五六七八九十]+)[点时](?:半|(?:[0-9]{1,2}|[一二三四五六七八九十]+)分)?(?=\s|,|花|买|吃|喝|付|收到|打车|$)'));
  mask(RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'));
  mask(RegExp(
      r'[0-9零〇一二两三四五六七八九十百千]+(?:分钟|小时|秒钟|秒|公里|千米|公斤|千克|毫升|升|厘米|平方米|个月|天|年|月|日|号|个|杯|件|瓶|份|斤|包|张|次|人|折|笔|期)(?![元块])'));
  return masked;
}

/// 去掉明确的否定短语（"不是买衣服，是打车" → "打车"）
String _withoutRejected(String text) {
  return text
      .replaceAll(RegExp(r'(?:不是|并非|不算)(?:(?![,;]|而是|是).)+?(?:[,;]\s*(?:而)?是|而是|是)'), ' ')
      .replaceAll(RegExp(r'(?:没有|还没|没|未)(?:有)?(?:收到|收入|到账|报销|退款|发工资)(?:工资|薪水|奖金|钱|款)?'), ' ');
}

/// 显式指定：「分类是餐饮」
String? _explicitCategory(String text, bool expense) {
  final String names = catsFor(expense).map((CategoryDef c) => c.name).join('|');
  final RegExpMatch? m = RegExp('分类(?:为|是|选|叫|记到)?\\s*($names)').firstMatch(text);
  if (m == null) return null;
  return catIdByName(m[1]!);
}

/// 历史备注推荐：返回 (分类, 是否存在歧义)
(String?, bool) _historyCategory(String text, List<NoteHint> history, bool expense) {
  final Map<String, int> score = <String, int>{};
  for (final NoteHint h in history) {
    if (h.text.length < 2 || !text.contains(h.text)) continue;
    final bool incomeCat = _incomeCats.contains(h.catId);
    if (incomeCat == expense) continue;
    score[h.catId] = (score[h.catId] ?? 0) + h.count;
  }
  if (score.isEmpty) return (null, false);
  final List<MapEntry<String, int>> list = score.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
  if (list.length > 1 && list[1].value * 2 > list.first.value) {
    return (null, true);
  }
  return (list.first.key, false);
}

// ------------------------------------------------------------------ 日期

class _DateHit {
  _DateHit(this.start, this.end, this.date, this.rank);
  final int start;
  final int end;
  final DateTime date;
  final int rank;
}

class _DateResult {
  const _DateResult(this.date, this.body, this.warnings);
  final DateTime date;
  final String body;
  final List<String> warnings;
}

const String _numWord = r'[0-9零〇一二两三四五六七八九十]+';

int? _dateInt(String source) {
  final double? v = cnNumber(source);
  return v == null ? null : v.round();
}

/// 解析中文日期表达，返回日期、剔除日期片段后的正文与警告。
_DateResult _parseDate(String text, DateTime now) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  final List<_DateHit> hits = <_DateHit>[];
  final List<String> warnings = <String>[];

  bool blocked(int start, int end) {
    final String before = text.substring(0, start);
    if (RegExp(r'(?:不是|并非|不要记|不记在)\s*$').hasMatch(before)) return true;
    final String after = text.substring(end);
    // 物体的日期不一定是付款日："今天买了明天的电影票"
    if (RegExp(r'^\s*的').hasMatch(after) &&
        RegExp(r'买|订|预订|预定|交|缴|付|支付|补交|报销').hasMatch(before)) {
      return true;
    }
    return false;
  }

  void collect(RegExp re, DateTime? Function(RegExpMatch) resolve, int rank) {
    for (final RegExpMatch m in re.allMatches(text)) {
      if (hits.any((_DateHit h) => m.start < h.end && m.end > h.start)) continue;
      if (blocked(m.start, m.end)) continue;
      final DateTime? d = resolve(m);
      if (d == null) continue;
      hits.add(_DateHit(m.start, m.end, d, rank));
    }
  }

  bool valid(int y, int mo, int d) {
    if (y < 1 || y > 9999 || mo < 1 || mo > 12 || d < 1 || d > 31) return false;
    final DateTime dt = DateTime(y, mo, d);
    return dt.year == y && dt.month == mo && dt.day == d;
  }

  DateTime at(int y, int mo, int d) => DateTime(y, mo, d, now.hour, now.minute);

  // 1) 2026-10-24 / 2026/10/24
  collect(RegExp(r'(?<![0-9])(\d{4})\s*[-/]\s*(\d{1,2})\s*[-/]\s*(\d{1,2})(?![0-9])'),
      (RegExpMatch m) {
    final int y = int.parse(m[1]!);
    final int mo = int.parse(m[2]!);
    final int d = int.parse(m[3]!);
    return valid(y, mo, d) ? at(y, mo, d) : null;
  }, 5);

  // 2) 今年 / 去年 / 前年 / 明年 / 2025年 + X月X日（号）
  collect(
      RegExp('(?:(今年|去年|前年|明年)|($_numWord)\\s*年)?\\s*'
          '($_numWord)\\s*月\\s*($_numWord)\\s*(?:[日号]|'
          '(?![0-9零〇一二两三四五六七八九十元块角毛分]))'),
      (RegExpMatch m) {
    final int offset = const <String, int>{'今年': 0, '去年': -1, '前年': -2, '明年': 1}[m[1]] ?? 0;
    final int? year = m[2] == null ? now.year + offset : _dateInt(m[2]!);
    final int? month = _dateInt(m[3]!);
    final int? day = _dateInt(m[4]!);
    if (year == null || month == null || day == null) return null;
    return valid(year, month, day) ? at(year, month, day) : null;
  }, 4);

  // 3) 上个月 8 号 / 这个月 15 号
  collect(RegExp('(上上个月|上个月|上月|这个月|本月|下个月|下月)\\s*($_numWord)\\s*[日号]'),
      (RegExpMatch m) {
    final int offset = const <String, int>{
      '上上个月': -2, '上个月': -1, '上月': -1, '这个月': 0, '本月': 0, '下个月': 1, '下月': 1,
    }[m[1]]!;
    final DateTime month = DateTime(now.year, now.month + offset, 1);
    final int? day = _dateInt(m[2]!);
    if (day == null) return null;
    return valid(month.year, month.month, day) ? at(month.year, month.month, day) : null;
  }, 4);

  // 4) 三天前 / 15 天前
  collect(RegExp('($_numWord)\\s*天(?:以)?前'), (RegExpMatch m) {
    final int? days = _dateInt(m[1]!);
    if (days == null || days < 0 || days > 3660) return null;
    return at(now.year, now.month, now.day - days);
  }, 3);

  // 5) 大前天 / 前天 / 昨天 / 昨晚 / 今天 / 明天 / 后天
  collect(RegExp(r'大前天|前天|昨天|昨晚|今天|今日|明天|后天'), (RegExpMatch m) {
    final int offset = const <String, int>{
      '大前天': -3, '前天': -2, '昨天': -1, '昨晚': -1,
      '今天': 0, '今日': 0, '明天': 1, '后天': 2,
    }[m[0]]!;
    return at(now.year, now.month, now.day + offset);
  }, 3);

  // 6) 周三 / 上周五 / 下周一 / 礼拜天
  collect(RegExp(r'(上上|上|这|本|下)?(?:周(?:星期|礼拜)?|星期|礼拜)([一二三四五六日天])'),
      (RegExpMatch m) {
    final int target = '一二三四五六日'.indexOf((m[2] ?? '').replaceAll('天', '日')) + 1;
    if (target < 1) return null;
    int offset = target - now.weekday;
    final String? week = m[1];
    if (week == null && offset > 0) offset -= 7;
    offset += (const <String, int>{'上上': -2, '上': -1, '这': 0, '本': 0, '下': 1}[week] ?? 0) * 7;
    return at(now.year, now.month, now.day + offset);
  }, 2);

  if (hits.isEmpty) {
    // 识别到但无法确定具体日期
    if (RegExp(r'上上个月|上个月|上月|本月|这个月|下个月|下月|去年|前年|上周末|前几天|最近几天|农历|春节|中秋|国庆|端午')
        .hasMatch(text)) {
      warnings.add('日期不明确，请核对');
    }
    return _DateResult(today, text, warnings);
  }

  hits.sort((_DateHit a, _DateHit b) =>
      a.rank != b.rank ? b.rank.compareTo(a.rank) : a.start.compareTo(b.start));
  final _DateHit selected = hits.first;
  if (DateTime(selected.date.year, selected.date.month, selected.date.day).isAfter(today)) {
    warnings.add('日期在未来，请核对日期和年份');
  }

  String body = text;
  final List<_DateHit> ordered = List<_DateHit>.of(hits)
    ..sort((_DateHit a, _DateHit b) => b.start.compareTo(a.start));
  for (final _DateHit h in ordered) {
    body = body.replaceRange(h.start, h.end, ' ' * (h.end - h.start));
  }
  return _DateResult(selected.date, body, warnings);
}

// ------------------------------------------------------------------ 金额

class _MoneyHit {
  _MoneyHit(this.value, this.start, this.end, this.priority);
  final double value;
  final int start;
  final int end;
  final int priority;
}

class _MoneyResult {
  const _MoneyResult(this.value, this.warnings);
  final double? value;
  final List<String> warnings;
}

const String _num =
    r'[0-9零〇一二两三四五六七八九十百千万亿]+(?:[.点][0-9零〇一二两三四五六七八九]+)?';

_MoneyResult _findMoney(String text) {
  final List<_MoneyHit> hits = <_MoneyHit>[];
  final List<String> warnings = <String>[];

  int priorityOf(int start) {
    final String prefix = text.substring(start > 12 ? start - 12 : 0, start);
    if (RegExp(r'不对|改成|改为|应该是|实际|实付|最后|最终').hasMatch(prefix)) return 3;
    if (RegExp(r'一共|总共|合计|总计').hasMatch(prefix)) return 2;
    return 0;
  }

  void add(RegExp pattern, double Function(RegExpMatch) value) {
    for (final RegExpMatch m in pattern.allMatches(text)) {
      if (hits.any((_MoneyHit h) => m.start < h.end && m.end > h.start)) continue;
      final double v = value(m);
      if (v <= 0 || v > 999999999) continue;
      hits.add(_MoneyHit(v, m.start, m.end, priorityOf(m.start)));
    }
  }

  // 1) 元 / 块，可带角、分与尾数：十五块五、三块二毛五、28元
  add(
    RegExp('($_num)\\s*(?:元|块|圆)(?:钱)?'
        '(?:\\s*($_num)\\s*(?:毛|角)(?:\\s*($_num)\\s*分?)?'
        '|\\s*($_num)\\s*分'
        '|\\s*($_num))?'),
    (RegExpMatch m) {
      double n = cnNumber(m[1]!) ?? 0;
      if (m[2] != null) n += (cnNumber(m[2]!) ?? 0) / 10;
      if (m[3] != null) n += (cnNumber(m[3]!) ?? 0) / 100;
      if (m[4] != null) n += (cnNumber(m[4]!) ?? 0) / 100;
      if (m[5] != null) {
        final String raw = m[5]!;
        final String digits = raw.replaceAllMapped(
            RegExp('[零〇一二两三四五六七八九]'), (Match x) => '${_digit[x[0]]}');
        n += (cnNumber(raw) ?? 0) / (digits.length <= 1 ? 10 : 100);
      }
      return n;
    },
  );

  // 2) 五毛 / 三角
  add(RegExp('($_num)\\s*(?:毛|角)(?:\\s*($_num)\\s*分?)?'), (RegExpMatch m) {
    return (cnNumber(m[1]!) ?? 0) / 10 + (m[2] == null ? 0 : (cnNumber(m[2]!) ?? 0) / 100);
  });

  // 3) 三分
  add(RegExp('($_num)\\s*分'), (RegExpMatch m) => (cnNumber(m[1]!) ?? 0) / 100);

  // 4) 人民币 / ¥ 前缀
  add(RegExp('(?:人民币|¥|￥)\\s*($_num)'), (RegExpMatch m) => cnNumber(m[1]!) ?? 0);

  // 5) 动词后的裸数字：花了 28、一共 300
  add(
    RegExp('(?:花了?|付了?|支付了?|支出|收入|收到|到账|金额|价格|付款|收款|赚了?|'
        '一共|总共|合计|实付|改成|改为|应该是)\\s*($_num)'),
    (RegExpMatch m) => cnNumber(m[1]!) ?? 0,
  );

  // 6) 兜底：任何数字，但排除数量 / 时长 / 日期单位（"两杯""30分钟""3号"）
  if (hits.isEmpty || hits.every((_MoneyHit h) => h.priority == 0)) {
    for (final RegExpMatch m in RegExp(_num).allMatches(text)) {
      if (hits.any((_MoneyHit h) => m.start < h.end && m.end > h.start)) continue;
      final String suffix = text.substring(m.end);
      if (RegExp(r'^\s*(?:个|杯|件|瓶|份|斤|公斤|千克|包|张|次|年|月|日|号|点|时|'
              '分钟|小时|公里|千米|人|折|笔|期|积分|分贝|码|成|岁|度|米|克|升)')
          .hasMatch(suffix)) {
        continue;
      }
      final double? v = cnNumber(m[0]!);
      if (v == null || v <= 0 || v > 999999999) continue;
      hits.add(_MoneyHit(v, m.start, m.end, 0));
    }
  }

  if (hits.isEmpty) return const _MoneyResult(null, <String>[]);

  if (hits.length == 1) {
    return _MoneyResult(hits.single.value, const <String>[]);
  }

  final List<_MoneyHit> prioritized = hits.where((_MoneyHit h) => h.priority > 0).toList()
    ..sort((_MoneyHit a, _MoneyHit b) =>
        a.priority != b.priority ? a.priority.compareTo(b.priority) : a.start.compareTo(b.start));
  if (prioritized.isNotEmpty) {
    warnings.add('包含多个金额，已采用总额或更正后的金额，请核对');
    return _MoneyResult(prioritized.last.value, warnings);
  }
  warnings.add('识别到多个金额，请填写本次总额；暂不自动合并多笔账');
  return _MoneyResult(hits.first.value, warnings);
}

/// 从整句里提炼备注：「买咖啡花了28块」→「咖啡」
String _cleanNote(String raw, String fallback) {
  String s = raw;
  // 金额片段
  s = s.replaceAll(RegExp('$_num\\s*(?:块钱|块|元|圆)'), ' ');
  s = s.replaceAll(RegExp('(?:人民币|¥|￥)\\s*$_num'), ' ');
  s = s.replaceAll(RegExp('(?:花了?|付了?|支付了?|一共|总共|合计|实付|金额|价格)\\s*$_num'), ' ');
  // 时间副词与口头语
  s = s.replaceAll(RegExp(r'刚才|刚刚|早上|中午|晚上|上午|下午|今天|昨天|前天|大概|差不多|左右'), ' ');
  // 记账口令
  s = s.replaceAll(RegExp(r'记一笔|帮我记|记一下|记个账|记一笔账'), ' ');
  s = s.replaceAll(RegExp(r'分类(?:为|是|选)?\s*[一-龥]{1,4}'), ' ');
  // 动词与收支词
  s = s.replaceAll(
      RegExp(r'买了|购买的|买了|购买|买的|买|吃了|吃的|喝了|喝的|收到|到账|支出|收入|花费|花了|支付了|支付|付款|付了|付给|消费|用了|一共|总共'), ' ');
  // 残留数字与标点
  s = s.replaceAll(RegExp(r'\d+(?:\.\d+)?'), ' ');
  s = s.replaceAll(RegExp(r'[，,。.、:：;；!！?？]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) s = fallback;
  return s.length > 14 ? s.substring(0, 14) : s;
}

// ------------------------------------------------------------------ 主入口

VoiceIntent parseVoice(String raw, {DateTime? now, List<NoteHint> history = const <NoteHint>[]}) {
  final DateTime today = now ?? DateTime.now();
  final List<String> warnings = <String>[];
  String body = _normalize(raw);
  final String source = body;

  // 显式备注："备注牛肉面，花了28元"
  String? explicitNote;
  final RegExpMatch? noteMarker =
      RegExp(r'(?:备注(?:为|是|叫|写)?|记作|标注(?:为|是)?)\s*[:：]?\s*').firstMatch(body);
  if (noteMarker != null) {
    final String tail = body.substring(noteMarker.end).trim();
    if (tail.isNotEmpty) {
      explicitNote = tail;
      body = '${body.substring(0, noteMarker.start)} ${tail.replaceAll(RegExp(r'[，,]?\s*\d+(?:\.\d+)?\s*(?:块钱|块|元)'), '')}';
    }
  }

  body = _withoutRejected(body);

  // 日期
  final _DateResult dateResult = _parseDate(body, today);
  warnings.addAll(dateResult.warnings);
  final DateTime date = dateResult.date;
  body = dateResult.body;

  // 金额（用遮蔽后的文本找钱，避免把"30分钟"当 30 元）
  final _MoneyResult money = _findMoney(_maskNonMoney(body));
  warnings.addAll(money.warnings);
  final double amount = money.value ?? 0;
  if (amount <= 0) warnings.add('没有听清金额，请补充');

  // 收支
  final String typeBody = _withoutRejected(body);
  final bool explicitIncome =
      RegExp(r'收入|进账|到账|收款|赚了|挣了|发工资|工资发了|领工资|报销|退款|退回|退了')
          .hasMatch(typeBody) ||
      RegExp(r'收到\s*(?:\d+|[一二两三四五六七八九十百千]+|钱|款|工资|薪水|奖金|红包|转账)')
          .hasMatch(_maskNonMoney(typeBody));
  final bool implicitIncome = RegExp(r'薪水|工资|奖金|利息|分红').hasMatch(typeBody) &&
      !RegExp(r'买|购买|花|支付|付给|转给|还没|没发|没有').hasMatch(body);
  final bool expenseCue =
      RegExp(r'买|花|支付|付了|付给|消费|支出|吃|喝|打车|充|交|还').hasMatch(body);
  final bool outgoing =
      RegExp(r'支出|转给|给别人|还给|付给|借给').hasMatch(typeBody);
  final bool expense =
      outgoing ? true : !(explicitIncome || (implicitIncome && !expenseCue));
  if (explicitIncome && RegExp('(?:花了?|支付了?|付了?)\\s*$_num').hasMatch(typeBody)) {
    warnings.add('同时提到收款和付款，请核对收支类型与金额');
  }

  // 分类：显式指定 > 关键词匹配 > 历史备注推荐
  final String otherId = expense ? 'other' : 'otherin';
  String catId = otherId;
  final String? explicit = _explicitCategory(body, expense);
  if (explicit != null) {
    catId = explicit;
  } else {
    int bestLen = 0;
    _catWords.forEach((String id, List<String> words) {
      final bool incomeCat = _incomeCats.contains(id);
      if (incomeCat == expense) return;
      for (final String w in words) {
        if (source.contains(w) && w.length > bestLen) {
          bestLen = w.length;
          catId = id;
        }
      }
    });
    if (catId == otherId && history.isNotEmpty) {
      final (String?, bool) hinted =
          _historyCategory('$body ${explicitNote ?? ''}', history, expense);
      if (hinted.$1 != null) {
        catId = hinted.$1!;
      } else if (hinted.$2) {
        warnings.add('历史备注有多个分类，请核对分类');
      }
    }
  }

  // 备注：去掉金额、时间副词、记账口令与动词，只留「买了什么」
  final String note = _cleanNote(explicitNote ?? body, catById(catId).name);

  return VoiceIntent(
    amount: amount,
    catId: catId,
    note: note,
    date: date,
    expense: expense,
    rawText: raw,
    warnings: List<String>.unmodifiable(warnings),
  );
}
