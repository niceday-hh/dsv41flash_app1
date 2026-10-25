import '../data.dart';

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

/// 中文数字 → 阿拉伯数字："二十八" → 28，"一百零五" → 105
double? cnNumber(String text) {
  if (text.isEmpty) return null;
  double total = 0;
  double section = 0;
  double number = 0;
  bool hasAny = false;
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
    } else {
      return null;
    }
  }
  if (!hasAny) return null;
  return total + section + number;
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

// ------------------------------------------------------------------ 日期

DateTime _parseDate(String text, DateTime today, void Function(String) consume) {
  DateTime date = DateTime(today.year, today.month, today.day);
  const Map<String, int> rel = <String, int>{
    '大前天': 3, '前天': 2, '昨天': 1, '昨晚': 1, '今早': 0, '今晚': 0, '今天': 0,
  };
  for (final MapEntry<String, int> e in rel.entries) {
    if (text.contains(e.key)) {
      consume(e.key);
      return date.subtract(Duration(days: e.value));
    }
  }
  final RegExpMatch? md = RegExp(r'(\d{1,2})月(\d{1,2})[日号]').firstMatch(text);
  if (md != null) {
    final int m = int.parse(md.group(1)!);
    final int d = int.parse(md.group(2)!);
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      final int year = m > today.month ? today.year - 1 : today.year;
      consume(md.group(0)!);
      return DateTime(year, m, d);
    }
  }
  final RegExpMatch? wk = RegExp(r'(?:周|星期)([一二三四五六日天])').firstMatch(text);
  if (wk != null) {
    const Map<String, int> wd = <String, int>{
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7,
    };
    final int target = wd[wk.group(1)!] ?? 1;
    int diff = today.weekday - target;
    if (diff <= 0) diff += 7;
    consume(wk.group(0)!);
    return date.subtract(Duration(days: diff));
  }
  if (text.contains('上个月')) {
    consume('上个月');
    return DateTime(today.year, today.month - 1, today.day);
  }
  if (text.contains('上月')) {
    consume('上月');
    return DateTime(today.year, today.month - 1, today.day);
  }
  return date;
}

// ------------------------------------------------------------------ 金额

class _MoneyHit {
  _MoneyHit(this.value, this.start, this.end, this.priority);
  final double value;
  final int start;
  final int end;
  final int priority;
}

_MoneyHit? _findMoney(String text) {
  final List<_MoneyHit> hits = <_MoneyHit>[];

  for (final RegExpMatch m
      in RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:块钱|块|元|圆)?').allMatches(text)) {
    final double v = double.tryParse(m.group(1)!) ?? 0;
    if (v <= 0) continue;
    final bool hasUnit = m.group(0)!.length > m.group(1)!.length;
    hits.add(_MoneyHit(v, m.start, m.end, hasUnit ? 10 : 5));
  }

  for (final RegExpMatch m in RegExp(
          r'([零〇一壹二两贰三叁四肆五伍六陆七柒八捌九玖十拾百佰千仟万]+)\s*(?:块钱|块|元|圆)')
      .allMatches(text)) {
    final double? v = cnNumber(m.group(1)!);
    if (v != null && v > 0) hits.add(_MoneyHit(v, m.start, m.end, 9));
  }

  // 角/毛：跟在"块/元"后的单个数字，累加到最近的金额上
  for (final RegExpMatch m
      in RegExp(r'(?:块|元)\s*([零一二两三四五六七八九\d])\s*(?:角|毛)?').allMatches(text)) {
    final String d = m.group(1)!;
    final double jiao = double.tryParse(d) ?? (_digit[d]?.toDouble() ?? 0);
    if (jiao <= 0 || jiao >= 10) continue;
    // 允许与"块/元"这个字符重叠一个位置（"十五块五" 中 块 既是单位的结尾也是角的开头）
    _MoneyHit? base;
    for (final _MoneyHit h in hits) {
      if (h.end <= m.start + 1 && (base == null || h.end > base.end)) base = h;
    }
    if (base == null) continue;
    final int idx = hits.indexOf(base);
    hits[idx] = _MoneyHit(base.value + jiao / 10, base.start, m.end, base.priority + 1);
  }

  // 4) 没有单位的中文数字（"买菜一百零五"），优先级最低
  if (hits.isEmpty) {
    for (final RegExpMatch m in RegExp(
            r'[零〇一壹二两贰三叁四肆五伍六陆七柒八捌九玖十拾百佰千仟万]+')
        .allMatches(text)) {
      final double? v = cnNumber(m.group(0)!);
      if (v != null && v > 0) hits.add(_MoneyHit(v, m.start, m.end, 1));
    }
  }

  if (hits.isEmpty) return null;
  hits.sort((_MoneyHit a, _MoneyHit b) {
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    return a.start.compareTo(b.start);
  });
  return hits.first;
}

// ------------------------------------------------------------------ 主入口

VoiceIntent parseVoice(String raw, {DateTime? now}) {
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
  final List<String> consumed = <String>[];
  final DateTime date = _parseDate(body, today, (String s) => consumed.add(s));
  for (final String c in consumed) {
    body = body.replaceFirst(c, ' ');
  }

  // 金额（用遮蔽后的文本找钱，避免把"30分钟"当 30 元）
  final _MoneyHit? hit = _findMoney(_maskNonMoney(body));
  final double amount = hit?.value ?? 0;
  if (amount <= 0) warnings.add('没有听清金额，请补充');
  if (amount > 999999999) warnings.add('金额超出合理范围');

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
  final bool expense = !(explicitIncome || (implicitIncome && !expenseCue));

  // 分类：关键词优先，更长的词胜出
  String catId = expense ? 'other' : 'otherin';
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

  // 备注
  String note = (explicitNote ?? body)
      .replaceAll(RegExp(r'(花了|花费|消费|支付|付了|付给|一共|总共|大概|差不多|用了|收到|收入|支出)'), ' ')
      .replaceAll(RegExp(r'(块钱|块|元|圆|人民币|整|钱)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  note = note.replaceAll(RegExp(r'^[\d\s.，,]+|[\d\s.，,]+$'), '').trim();
  if (note.isEmpty) note = catById(catId).name;
  if (note.length > 14) note = note.substring(0, 14);

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
