import '../data.dart';
import '../models.dart';

class NoteChoice {
  NoteChoice(this.text, this.latest);
  final String text;
  DateTime latest;
  int count = 0;
  final Map<String, NoteCategoryUsage> categoryUsage = {};
}
class NoteCategoryUsage {
  NoteCategoryUsage(this.latest);
  DateTime latest;
  int count = 0;
}
class NoteCatalog {
  NoteCatalog.fromChoices({required this.expense, required this.income});
  final List<NoteChoice> expense, income;
  List<NoteChoice> forMode(bool isIncome) => isIncome ? income : expense;
}

/// One statistic per literal remark AND category, never an arbitrary first cat.
class NoteHint {
  const NoteHint(this.text, this.catId, this.count, {this.latest});
  final String text, catId;
  final int count;
  final DateTime? latest;
}

List<NoteHint> voiceHistory(Iterable<Bill> bills) {
  final Map<(String, String), NoteHint> stats = {};
  for (final b in bills) {
    final text = b.note.trim();
    if (text.isEmpty || catById(b.catId).expense != b.expense) continue;
    final key = (text, b.catId);
    final previous = stats[key];
    stats[key] = NoteHint(text, b.catId, (previous?.count ?? 0) + 1,
      latest: previous == null || b.date.isAfter(previous.latest!) ? b.date : previous.latest);
  }
  return List.unmodifiable(stats.values);
}

NoteCatalog catalogFromHints(List<NoteHint> hints, DateTime now) {
  final maps = <bool, Map<String, NoteChoice>>{false: {}, true: {}};
  for (final hint in hints) {
    if (hint.count <= 0 || hint.text.trim().isEmpty) continue;
    final matches = [...kExpenseCats, ...kIncomeCats].where((c) => c.id == hint.catId);
    if (matches.isEmpty) continue;
    final cat = matches.first;
    final latest = hint.latest ?? now;
    final note = maps[!cat.expense]!.putIfAbsent(hint.text, () => NoteChoice(hint.text, latest));
    note.count += hint.count;
    if (latest.isAfter(note.latest)) note.latest = latest;
    final usage = note.categoryUsage.putIfAbsent(cat.name, () => NoteCategoryUsage(latest));
    usage.count += hint.count;
    if (latest.isAfter(usage.latest)) usage.latest = latest;
  }
  return NoteCatalog.fromChoices(expense: maps[false]!.values.toList(), income: maps[true]!.values.toList());
}
