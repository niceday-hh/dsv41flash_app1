import '../data.dart';

/// 语音记账解析结果
class VoiceIntent {
  final double amount;
  final String catId;
  final String note;
  final DateTime date;
  final bool expense;

  const VoiceIntent({
    required this.amount,
    required this.catId,
    required this.note,
    required this.date,
    this.expense = true,
  });

  bool get valid => amount > 0;
}

const Map<String, List<String>> _catWords = <String, List<String>>{
  'food': <String>['吃', '饭', '早餐', '午餐', '晚餐', '午饭', '晚饭', '外卖', '奶茶', '咖啡', '水果', '零食', '火锅', '烧烤', '饮料', '面条', '包子', '超市买菜', '菜'],
  'traffic': <String>['打车', '地铁', '公交', '高铁', '火车', '机票', '油', '停车', '滴滴', '出租车', '车费'],
  'shop': <String>['买', '衣服', '鞋', '包', '化妆品', '护肤', '日用品', '淘宝', '京东', '快递'],
  'fun': <String>['电影', '游戏', '娱乐', 'KTV', '唱歌', '健身', '演出', '门票'],
  'home': <String>['房租', '水费', '电费', '燃气', '物业', '水电'],
  'phone': <String>['话费', '流量', '手机费', '宽带'],
  'health': <String>['药', '医院', '看病', '体检', '挂号', '医疗'],
  'study': <String>['书', '学习', '课程', '培训', '文具', '打印'],
  'travel': <String>['旅行', '旅游', '酒店', '民宿', '景点'],
  'pet': <String>['猫粮', '狗粮', '宠物', '猫砂'],
  'beauty': <String>['理发', '美容', '美甲', 'SPA'],
  'salary': <String>['工资', '薪水', '发工资'],
  'bonus': <String>['奖金', '年终奖', '提成'],
  'invest': <String>['理财', '基金', '股票', '分红', '利息'],
  'gift': <String>['红包', '礼金', '压岁钱'],
};

const List<String> _incomeWords = <String>['收入', '收到', '工资', '奖金', '红包', '报销', '退款', '进账'];

const Map<String, int> _digit = <String, int>{
  '零': 0, '〇': 0, '一': 1, '壹': 1, '二': 2, '两': 2, '贰': 2, '三': 3, '叁': 3,
  '四': 4, '肆': 4, '五': 5, '伍': 5, '六': 6, '陆': 6, '七': 7, '柒': 7, '八': 8,
  '捌': 8, '九': 9, '玖': 9,
};

const Map<String, int> _unit = <String, int>{
  '十': 10, '拾': 10, '百': 100, '佰': 100, '千': 1000, '仟': 1000, '万': 10000,
};

/// 中文数字 → 阿拉伯数字，"二十八" → 28，"一百零五" → 105
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
      if (u == 10000) {
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

/// 解析一句口语，例如「午饭花了二十八块五」
VoiceIntent parseVoice(String raw, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  String text = raw
      .replaceAll(RegExp(r'[，。！？、,.!?]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final String source = text;

  bool expense = true;
  for (final String w in _incomeWords) {
    if (text.contains(w) && !text.contains('花') && !text.contains('买')) {
      expense = false;
      break;
    }
  }

  DateTime date = DateTime(today.year, today.month, today.day);
  if (text.contains('大前天')) {
    date = date.subtract(const Duration(days: 3));
    text = text.replaceAll('大前天', ' ');
  } else if (text.contains('前天')) {
    date = date.subtract(const Duration(days: 2));
    text = text.replaceAll('前天', ' ');
  } else if (text.contains('昨天')) {
    date = date.subtract(const Duration(days: 1));
    text = text.replaceAll('昨天', ' ');
  } else if (text.contains('今天')) {
    text = text.replaceAll('今天', ' ');
  }

  double amount = 0;
  // 1) 阿拉伯数字 + 单位
  final RegExpMatch? arabic = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块钱|块|元|圆|rmb|RMB)?').firstMatch(text);
  if (arabic != null) {
    amount = double.tryParse(arabic.group(1)!) ?? 0;
    // 角/毛
    final RegExpMatch? jiao = RegExp(r'(?:块|元)\s*([一二三四五六七八九\d])\s*(?:角|毛)').firstMatch(text);
    if (jiao != null) {
      final String j = jiao.group(1)!;
      final double v = double.tryParse(j) ?? (_digit[j]?.toDouble() ?? 0);
      amount += v / 10;
    } else {
      final RegExpMatch? tail = RegExp(r'(?:块|元)\s*([一二三四五六七八九])(?!\s*[个只件次天])').firstMatch(text);
      if (tail != null) {
        amount += (_digit[tail.group(1)!] ?? 0) / 10;
      }
    }
    text = text.replaceFirst(arabic.group(0)!, ' ');
  } else {
    // 2) 中文数字 + 单位
    final RegExpMatch? cn = RegExp(r'([零〇一壹二两贰三叁四肆五伍六陆七柒八捌九玖十拾百佰千仟万]+)\s*(?:块钱|块|元|圆)').firstMatch(text);
    if (cn != null) {
      amount = cnNumber(cn.group(1)!) ?? 0;
      final RegExpMatch? tail = RegExp(r'(?:块|元)\s*([一二三四五六七八九])').firstMatch(text);
      if (tail != null) amount += (_digit[tail.group(1)!] ?? 0) / 10;
      text = text.replaceFirst(cn.group(0)!, ' ');
    } else {
      final RegExpMatch? bare = RegExp(r'([零〇一壹二两贰三叁四肆五伍六陆七柒八捌九玖十拾百佰千仟万]+)').firstMatch(text);
      if (bare != null) {
        final double? v = cnNumber(bare.group(1)!);
        if (v != null && v > 0) {
          amount = v;
          text = text.replaceFirst(bare.group(0)!, ' ');
        }
      }
    }
  }

  String catId = expense ? 'other' : 'otherin';
  int bestLen = 0;
  _catWords.forEach((String id, List<String> words) {
    final bool incomeCat = <String>['salary', 'bonus', 'invest', 'gift'].contains(id);
    if (incomeCat == expense) return;
    for (final String w in words) {
      if (source.contains(w) && w.length > bestLen) {
        bestLen = w.length;
        catId = id;
      }
    }
  });

  String note = text
      .replaceAll(RegExp(r'(花了|花费|消费|支付|付了|一共|总共|大概|差不多|用了|收到|收入)'), ' ')
      .replaceAll(RegExp(r'(钱|人民币|整)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (note.isEmpty) note = catById(catId).name;
  if (note.length > 12) note = note.substring(0, 12);

  return VoiceIntent(amount: amount, catId: catId, note: note, date: date, expense: expense);
}
