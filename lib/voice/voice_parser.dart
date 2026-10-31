import 'package:flutter/foundation.dart';
import '../data.dart';
import 'note_history.dart';
import 'parser_core.dart' as core;
export 'note_history.dart' show NoteHint, voiceHistory;
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

  bool get valid => amount > 0 && amount <= 999999999;

  VoiceIntent copyWith({
    double? amount,
    String? catId,
    String? note,
    DateTime? date,
    bool? expense,
  }) {
    final List<String> w = warnings.where((String s) {
      if (amount != null && (s.contains('金额') || s.contains('总额'))) return false;
      if (catId != null && (s.contains('分类') || s.contains('用途'))) return false;
      if (date != null && s.contains('日期')) return false;
      return true;
    }).toList();
    if (amount != null && (amount <= 0 || amount > 999999999)) {
      w.add('金额需大于零且不超过九位数字');
    }
    if (catId != null && (catId == 'other' || catId == 'otherin')) w.add('用途不明确，请选择分类');
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


// Core rules ported from 拾光账本 v3.1.4. The public result keeps Whale's
// category IDs, compact automatic remarks and existing editor interactions.
VoiceIntent parseVoice(String raw, {DateTime? now, List<NoteHint> history = const [],
    bool? expenseOverride, String? noteOverride}) {
  final clock = now ?? DateTime.now();
  final normalized = raw.replaceAllMapped(RegExp('[壹贰叁肆伍陆柒捌玖拾佰仟]'),
    (m) => const {'壹':'一','贰':'二','叁':'三','肆':'四','伍':'五','陆':'六',
      '柒':'七','捌':'八','玖':'九','拾':'十','佰':'百','仟':'千'}[m[0]]!);
  final draft = core.parseVoiceEntry(normalized, now: clock,
    catalog: catalogFromHints(history, clock),
    incomeOverride: expenseOverride == null ? null : !expenseOverride, noteOverride: noteOverride);
  final cats = catsFor(!draft.isIncome);
  final cat = cats.firstWhere((c) => c.name == draft.category, orElse: () => cats.last);
  var note = draft.note;
  // Preserve Whale's concise generated remark. Explicit/manual remarks retain
  // their complete text (including quantities, dates and merchant names).
  if (noteOverride == null && !RegExp(r'备注|记作|标注').hasMatch(raw)) {
    note = note.replaceAll(RegExp(r'吃了|喝了|购买的|购买|大概|差不多|左右'), ' ').trim();
    if (note.length > 14) note = note.substring(0, 14);
  }
  final warnings = [...draft.warnings];
  if (draft.categorySuggestions.length > 1 && draft.category == '其他') {
    warnings.add('候选分类：${draft.categorySuggestions.map((s) => s.category).join('、')}');
  }
  return VoiceIntent(amount: draft.amount ?? 0, catId: cat.id, note: note,
    date: draft.date, expense: !draft.isIncome, rawText: raw, warnings: List.unmodifiable(warnings));
}

Future<VoiceIntent> parseVoiceAsync(String text, {DateTime? now,
    List<NoteHint> history = const [], bool? expenseOverride, String? noteOverride}) {
  final input = (text: text, now: now ?? DateTime.now(), history: history,
    expense: expenseOverride, note: noteOverride);
  return history.length >= 200 ? compute(_parseInBackground, input, debugLabel: 'voice-personal-rules')
    : Future.value(_parseInBackground(input));
}
typedef _ParseInput = ({String text, DateTime now, List<NoteHint> history, bool? expense, String? note});
VoiceIntent _parseInBackground(_ParseInput input) => parseVoice(input.text, now: input.now,
  history: input.history, expenseOverride: input.expense, noteOverride: input.note);

// Public helper retained for compatibility with v1.5.7 callers.
double? cnNumber(String text) => text.isEmpty ? null : core.mandarinNumber(text);
