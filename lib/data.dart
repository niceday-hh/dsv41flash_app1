import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

const List<CategoryDef> kExpenseCats = <CategoryDef>[
  CategoryDef(id: 'food', name: '餐饮', icon: Icons.ramen_dining_rounded, color: Color(0xFFFF8A65), expense: true),
  CategoryDef(id: 'traffic', name: '交通', icon: Icons.directions_subway_rounded, color: Color(0xFF5C9DFF), expense: true),
  CategoryDef(id: 'shop', name: '购物', icon: Icons.shopping_bag_rounded, color: Color(0xFFFF6FA5), expense: true),
  CategoryDef(id: 'fun', name: '娱乐', icon: Icons.sports_esports_rounded, color: Color(0xFF9B8CFF), expense: true),
  CategoryDef(id: 'home', name: '居住', icon: Icons.home_rounded, color: Color(0xFF4DB6AC), expense: true),
  CategoryDef(id: 'phone', name: '通讯', icon: Icons.smartphone_rounded, color: Color(0xFF64B5F6), expense: true),
  CategoryDef(id: 'health', name: '医疗', icon: Icons.medical_services_rounded, color: Color(0xFF4DD0A5), expense: true),
  CategoryDef(id: 'study', name: '学习', icon: Icons.menu_book_rounded, color: Color(0xFF7E8CE0), expense: true),
  CategoryDef(id: 'travel', name: '旅行', icon: Icons.flight_takeoff_rounded, color: Color(0xFF26C6DA), expense: true),
  CategoryDef(id: 'pet', name: '宠物', icon: Icons.pets_rounded, color: Color(0xFFFFA726), expense: true),
  CategoryDef(id: 'beauty', name: '美容', icon: Icons.spa_rounded, color: Color(0xFFF48FB1), expense: true),
  CategoryDef(id: 'other', name: '其他', icon: Icons.more_horiz_rounded, color: Color(0xFF90A4AE), expense: true),
];

const List<CategoryDef> kIncomeCats = <CategoryDef>[
  CategoryDef(id: 'salary', name: '工资', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF14C08A), expense: false),
  CategoryDef(id: 'bonus', name: '奖金', icon: Icons.emoji_events_rounded, color: Color(0xFFFFB74D), expense: false),
  CategoryDef(id: 'invest', name: '理财', icon: Icons.trending_up_rounded, color: Color(0xFF4FC3F7), expense: false),
  CategoryDef(id: 'gift', name: '红包', icon: Icons.card_giftcard_rounded, color: Color(0xFFFF8A80), expense: false),
  CategoryDef(id: 'parttime', name: '兼职', icon: Icons.work_rounded, color: Color(0xFF9CCC65), expense: false),
  CategoryDef(id: 'otherin', name: '其他', icon: Icons.add_circle_outline_rounded, color: Color(0xFF90A4AE), expense: false),
];

List<CategoryDef> catsFor(bool expense) => expense ? kExpenseCats : kIncomeCats;

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
  _Seed('food', '午饭 · 麻辣烫', 18, 42, 6),
  _Seed('food', '早餐 · 豆浆油条', 6, 15, 4),
  _Seed('food', '晚饭 · 小炒', 32, 88, 5),
  _Seed('food', '咖啡 拿铁', 18, 38, 3),
  _Seed('food', '奶茶', 12, 26, 3),
  _Seed('food', '周末聚餐', 120, 320, 1),
  _Seed('traffic', '地铁通勤', 3, 9, 6),
  _Seed('traffic', '打车回家', 22, 56, 3),
  _Seed('traffic', '公交', 2, 4, 3),
  _Seed('shop', '超市采购', 45, 180, 4),
  _Seed('shop', '衣服', 129, 499, 1),
  _Seed('shop', '日用品', 20, 80, 3),
  _Seed('fun', '电影票', 45, 90, 1),
  _Seed('fun', '健身课', 60, 200, 1),
  _Seed('fun', '游戏充值', 30, 128, 1),
  _Seed('phone', '话费充值', 50, 100, 1),
  _Seed('health', '感冒药', 25, 68, 1),
  _Seed('study', '书店买书', 38, 120, 1),
  _Seed('travel', '周末出行', 200, 600, 1),
  _Seed('pet', '猫粮', 68, 168, 1),
  _Seed('beauty', '理发', 45, 120, 1),
  _Seed('other', '快递费', 8, 20, 1),
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
