import 'package:flutter/material.dart';

/// 记账分类定义
class CategoryDef {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool expense;

  const CategoryDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.expense = true,
  });
}

/// 一条账单记录
class Bill {
  final String id;
  final String catId;
  final double amount; // 始终为正数
  final bool expense;
  final DateTime date;
  final String note;

  Bill({
    required this.id,
    required this.catId,
    required this.amount,
    required this.expense,
    required this.date,
    this.note = '',
  });

  Bill copyWith({
    String? catId,
    double? amount,
    bool? expense,
    DateTime? date,
    String? note,
  }) {
    return Bill(
      id: id,
      catId: catId ?? this.catId,
      amount: amount ?? this.amount,
      expense: expense ?? this.expense,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'c': catId,
        'a': amount,
        'e': expense,
        't': date.millisecondsSinceEpoch,
        'n': note,
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        catId: j['c'] as String,
        amount: (j['a'] as num).toDouble(),
        expense: j['e'] as bool,
        date: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        note: (j['n'] as String?) ?? '',
      );
}

/// 某一天的账单分组
class DayGroup {
  final DateTime day;
  final List<Bill> bills;
  final double expense;
  final double income;

  DayGroup(this.day, this.bills, this.expense, this.income);
}
