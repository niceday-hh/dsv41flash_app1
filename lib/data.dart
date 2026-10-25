import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

// 与「拾光账本 3.1.4」对齐的完整分类体系：34 个支出 + 8 个收入
const List<CategoryDef> kExpenseCats = <CategoryDef>[
  CategoryDef(id: 'food', name: '餐饮', icon: Icons.ramen_dining_rounded, color: Color(0xFFFF8A65), expense: true),
  CategoryDef(id: 'shop', name: '购物', icon: Icons.shopping_bag_rounded, color: Color(0xFFFF6FA5), expense: true),
  CategoryDef(id: 'daily', name: '日用', icon: Icons.soap_rounded, color: Color(0xFF4DB6AC), expense: true),
  CategoryDef(id: 'traffic', name: '交通', icon: Icons.directions_subway_rounded, color: Color(0xFF5C9DFF), expense: true),
  CategoryDef(id: 'veg', name: '蔬菜', icon: Icons.agriculture_rounded, color: Color(0xFF66BB6A), expense: true),
  CategoryDef(id: 'fruit', name: '水果', icon: Icons.eco_rounded, color: Color(0xFF9CCC65), expense: true),
  CategoryDef(id: 'snack', name: '零食', icon: Icons.cookie_rounded, color: Color(0xFFFFB74D), expense: true),
  CategoryDef(id: 'sport', name: '运动', icon: Icons.fitness_center_rounded, color: Color(0xFF9B8CFF), expense: true),
  CategoryDef(id: 'fun', name: '娱乐', icon: Icons.sports_esports_rounded, color: Color(0xFFA78BFA), expense: true),
  CategoryDef(id: 'phone', name: '通讯', icon: Icons.smartphone_rounded, color: Color(0xFF64B5F6), expense: true),
  CategoryDef(id: 'cloth', name: '服饰', icon: Icons.checkroom_rounded, color: Color(0xFFF48FB1), expense: true),
  CategoryDef(id: 'beauty', name: '美容', icon: Icons.spa_rounded, color: Color(0xFFF06292), expense: true),
  CategoryDef(id: 'home', name: '住房', icon: Icons.home_rounded, color: Color(0xFF4DB6AC), expense: true),
  CategoryDef(id: 'house', name: '居家', icon: Icons.chair_rounded, color: Color(0xFFA1887F), expense: true),
  CategoryDef(id: 'child', name: '孩子', icon: Icons.child_care_rounded, color: Color(0xFFFFCA28), expense: true),
  CategoryDef(id: 'elder', name: '长辈', icon: Icons.elderly_rounded, color: Color(0xFFBCAAA4), expense: true),
  CategoryDef(id: 'social', name: '社交', icon: Icons.groups_rounded, color: Color(0xFF7986CB), expense: true),
  CategoryDef(id: 'travel', name: '旅行', icon: Icons.flight_takeoff_rounded, color: Color(0xFF26C6DA), expense: true),
  CategoryDef(id: 'wine', name: '烟酒', icon: Icons.wine_bar_rounded, color: Color(0xFFE57373), expense: true),
  CategoryDef(id: 'digital', name: '数码', icon: Icons.devices_rounded, color: Color(0xFF5C9DFF), expense: true),
  CategoryDef(id: 'car', name: '汽车', icon: Icons.local_gas_station_rounded, color: Color(0xFF5C7CFA), expense: true),
  CategoryDef(id: 'health', name: '医疗', icon: Icons.medical_services_rounded, color: Color(0xFF4DD0A5), expense: true),
  CategoryDef(id: 'book', name: '书籍', icon: Icons.auto_stories_rounded, color: Color(0xFF7E8CE0), expense: true),
  CategoryDef(id: 'study', name: '学习', icon: Icons.school_rounded, color: Color(0xFF7986CB), expense: true),
  CategoryDef(id: 'pet', name: '宠物', icon: Icons.pets_rounded, color: Color(0xFFFFA726), expense: true),
  CategoryDef(id: 'giftout', name: '礼金', icon: Icons.card_giftcard_rounded, color: Color(0xFFFF8A80), expense: true),
  CategoryDef(id: 'present', name: '礼物', icon: Icons.redeem_rounded, color: Color(0xFFFF80AB), expense: true),
  CategoryDef(id: 'office', name: '办公', icon: Icons.business_center_rounded, color: Color(0xFF78909C), expense: true),
  CategoryDef(id: 'repair', name: '维修', icon: Icons.handyman_rounded, color: Color(0xFF90A4AE), expense: true),
  CategoryDef(id: 'donate', name: '捐赠', icon: Icons.volunteer_activism_rounded, color: Color(0xFFEF9A9A), expense: true),
  CategoryDef(id: 'lottery', name: '彩票', icon: Icons.casino_rounded, color: Color(0xFF81C784), expense: true),
  CategoryDef(id: 'relative', name: '亲友', icon: Icons.people_rounded, color: Color(0xFFFFAB91), expense: true),
  CategoryDef(id: 'express', name: '快递', icon: Icons.local_shipping_rounded, color: Color(0xFF90A4AE), expense: true),
  CategoryDef(id: 'other', name: '其他', icon: Icons.more_horiz_rounded, color: Color(0xFF90A4AE), expense: true),
];

const List<CategoryDef> kIncomeCats = <CategoryDef>[
  CategoryDef(id: 'salary', name: '工资', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF14C08A), expense: false),
  CategoryDef(id: 'parttime', name: '兼职', icon: Icons.work_rounded, color: Color(0xFF26C6DA), expense: false),
  CategoryDef(id: 'invest', name: '理财', icon: Icons.trending_up_rounded, color: Color(0xFF4FC3F7), expense: false),
  CategoryDef(id: 'gift', name: '礼金', icon: Icons.card_giftcard_rounded, color: Color(0xFFFF8A80), expense: false),
  CategoryDef(id: 'bonus', name: '奖金', icon: Icons.emoji_events_rounded, color: Color(0xFFFFB74D), expense: false),
  CategoryDef(id: 'reimburse', name: '报销', icon: Icons.receipt_long_rounded, color: Color(0xFF66BB6A), expense: false),
  CategoryDef(id: 'refund', name: '退款', icon: Icons.undo_rounded, color: Color(0xFF64B5F6), expense: false),
  CategoryDef(id: 'otherin', name: '其他', icon: Icons.add_circle_outline_rounded, color: Color(0xFF90A4AE), expense: false),
];

/// 记账面板首页展示的常用分类顺序（其余在「全部」里）
const List<String> kFrequentCatIds = <String>[
  'food', 'traffic', 'shop', 'daily', 'fun', 'phone', 'health', 'study',
  'veg', 'fruit', 'snack', 'sport',
];

List<CategoryDef> catsFor(bool expense) => expense ? kExpenseCats : kIncomeCats;

/// 中文分类名 → 分类 id（用于 CSV 导入与语音）
String catIdByName(String name) {
  final String key = name.trim();
  for (final CategoryDef c in kExpenseCats) {
    if (c.name == key) return c.id;
  }
  for (final CategoryDef c in kIncomeCats) {
    if (c.name == key) return c.id;
  }
  const Map<String, String> alias = <String, String>{
    // 支出别名
    '吃饭': 'food', '食物': 'food', '外卖': 'food', '聚餐': 'food',
    '出行': 'traffic', '车费': 'traffic', '打车': 'traffic',
    '超市': 'shop', '网购': 'shop',
    '房租': 'home', '水电': 'home', '物业': 'home', '居住': 'home',
    '话费': 'phone', '流量': 'phone',
    '健身': 'sport', '运动健身': 'sport',
    '电影': 'fun', '游戏': 'fun', '娱乐活动': 'fun',
    '化妆品': 'beauty', '理发': 'beauty',
    '日用品': 'daily', '生活用品': 'daily',
    '书': 'book', '图书': 'book',
    '课程': 'study', '培训': 'study', '学费': 'study',
    '猫粮': 'pet', '狗粮': 'pet',
    '红包': 'gift',
    '快递费': 'express',
    '烟': 'wine', '酒': 'wine',
    '手机': 'digital', '电脑': 'digital',
    '加油': 'car', '停车': 'car',
    // 收入别名
    '薪水': 'salary', '月薪': 'salary', '发工资': 'salary',
    '年终奖': 'bonus', '提成': 'bonus',
    '投资': 'invest', '股票': 'invest', '基金': 'invest', '分红': 'invest',
    '返还': 'refund', '退回': 'refund',
    '其他收入': 'otherin',
  };
  return alias[key] ?? 'other';
}

CategoryDef catById(String id) {
  for (final CategoryDef c in kExpenseCats) {
    if (c.id == id) return c;
  }
  for (final CategoryDef c in kIncomeCats) {
    if (c.id == id) return c;
  }
  return kExpenseCats.last;
}

class _Seed {
  final String cat;
  final String note;
  final double min;
  final double max;
  final int weight;
  const _Seed(this.cat, this.note, this.min, this.max, this.weight);
}

const List<_Seed> _seeds = <_Seed>[
  // 餐饮
  _Seed('food', '午饭 · 麻辣烫', 18, 42, 6),
  _Seed('food', '早餐 · 豆浆油条', 6, 15, 4),
  _Seed('food', '晚饭 · 小炒', 32, 88, 5),
  _Seed('food', '咖啡 拿铁', 18, 38, 3),
  // 交通
  _Seed('traffic', '地铁通勤', 3, 9, 6),
  _Seed('traffic', '打车回家', 22, 56, 3),
  _Seed('traffic', '公交', 2, 4, 3),
  // 日用与吃
  _Seed('daily', '纸巾洗衣液', 25, 90, 2),
  _Seed('veg', '菜市场', 12, 45, 3),
  _Seed('fruit', '水果店', 15, 58, 2),
  _Seed('snack', '零食', 8, 36, 2),
  // 购物
  _Seed('shop', '超市采购', 45, 180, 4),
  _Seed('cloth', '衣服', 129, 499, 1),
  _Seed('digital', '数码配件', 59, 399, 1),
  // 生活
  _Seed('sport', '健身房', 60, 200, 1),
  _Seed('fun', '电影票', 45, 90, 1),
  _Seed('fun', '游戏充值', 30, 128, 1),
  _Seed('phone', '话费充值', 50, 100, 1),
  _Seed('health', '感冒药', 25, 68, 1),
  _Seed('book', '书店买书', 38, 120, 1),
  _Seed('study', '线上课程', 99, 299, 1),
  _Seed('pet', '猫粮', 68, 168, 1),
  _Seed('beauty', '理发', 45, 120, 1),
  _Seed('social', '同事聚餐', 120, 320, 1),
  _Seed('travel', '周边游', 200, 600, 1),
  _Seed('office', '办公用品', 20, 88, 1),
  _Seed('express', '快递费', 8, 20, 1),
  _Seed('house', '家居收纳', 39, 159, 1),
  _Seed('wine', '精酿', 45, 128, 1),
  _Seed('other', '杂项', 10, 40, 1),
];

/// 生成最近 6 个月的演示账单，数据固定可复现
List<Bill> buildSeedBills() {
  final Random rnd = Random(20261024);
  final DateTime now = DateTime.now();
  final List<Bill> out = <Bill>[];

  for (int m = 5; m >= 0; m--) {
    final DateTime monthStart = DateTime(now.year, now.month - m, 1);
    final int lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final int maxDay = m == 0 ? now.day : lastDay;
    final bool partial = m == 0 && now.day < lastDay;
    final int count = partial ? 22 + rnd.nextInt(10) : 20 + rnd.nextInt(12);

    if (maxDay >= 10) {
      out.add(Bill(
        id: 'seed_salary_${monthStart.year}_${monthStart.month}',
        catId: 'salary',
        amount: 22800.0 + rnd.nextInt(4) * 500,
        expense: false,
        date: DateTime(monthStart.year, monthStart.month, 10, 9, 30),
        note: '月度薪资',
      ));
    }
    if (rnd.nextInt(10) > 6 && maxDay >= 15) {
      out.add(Bill(
        id: 'seed_gift_${monthStart.year}_${monthStart.month}',
        catId: 'gift',
        amount: 200.0 + rnd.nextInt(12) * 50,
        expense: false,
        date: DateTime(monthStart.year, monthStart.month, 15, 20, 12),
        note: '朋友红包',
      ));
    }

    // 固定支出：房租 + 水电
    if (maxDay >= 5) {
      out.add(Bill(
        id: 'seed_rent_${monthStart.year}_${monthStart.month}',
        catId: 'home',
        amount: 2600,
        expense: true,
        date: DateTime(monthStart.year, monthStart.month, 5, 10, 0),
        note: '房租',
      ));
      out.add(Bill(
        id: 'seed_util_${monthStart.year}_${monthStart.month}',
        catId: 'home',
        amount: 120.0 + rnd.nextInt(16) * 10,
        expense: true,
        date: DateTime(monthStart.year, monthStart.month, 5, 10, 20),
        note: '水电燃气',
      ));
    }

    for (int i = 0; i < count; i++) {
      final _Seed s = _weighted(rnd);
      final int day = 1 + rnd.nextInt(maxDay);
      final double amt = s.min + rnd.nextDouble() * (s.max - s.min);
      out.add(Bill(
        id: 'seed_${monthStart.year}_${monthStart.month}_$i',
        catId: s.cat,
        amount: double.parse(amt.toStringAsFixed(2)),
        expense: true,
        date: DateTime(monthStart.year, monthStart.month, day, 8 + rnd.nextInt(13), rnd.nextInt(60)),
        note: s.note,
      ));
    }
  }
  out.sort((Bill a, Bill b) => b.date.compareTo(a.date));
  return out;
}

_Seed _weighted(Random rnd) {
  int total = 0;
  for (final _Seed s in _seeds) {
    total += s.weight;
  }
  int r = rnd.nextInt(total);
  for (final _Seed s in _seeds) {
    r -= s.weight;
    if (r < 0) return s;
  }
  return _seeds.first;
}

/// 默认分类预算
Map<String, double> defaultBudgets() => <String, double>{
      'food': 1800,
      'shop': 1200,
      'traffic': 600,
      'fun': 500,
      'home': 3000,
    };
