import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// 更换分类：搜索 + 最近使用 + 全部分类网格。
Future<String?> showCategoryPicker(
  BuildContext context, {
  required bool expense,
  required String current,
  List<String> recent = const <String>[],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _CategoryPickerSheet(
      expense: expense,
      current: current,
      recent: recent,
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    Key? key,
    required this.expense,
    required this.current,
    required this.recent,
  }) : super(key: key);

  final bool expense;
  final String current;
  final List<String> recent;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CategoryDef> get _all => catsFor(widget.expense);

  List<CategoryDef> get _filtered {
    final String q = _q.trim();
    if (q.isEmpty) return _all;
    return _all.where((CategoryDef c) => c.name.contains(q)).toList();
  }

  void _choose(CategoryDef c) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, c.id);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final List<CategoryDef> filtered = _filtered;
    final List<CategoryDef> recents = widget.recent
        .map(catById)
        .where((CategoryDef c) => c.expense == widget.expense)
        .toList();
    final bool showRecent = _q.trim().isEmpty && recents.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.74),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration:
                    BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Text('更换分类', style: T.h2(p).copyWith(fontSize: 16)),
                const SizedBox(width: 8),
                Text('${_all.length} 个', style: TextStyle(fontSize: 11, color: p.ink3)),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: p.cardSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.close_rounded, size: 15, color: p.ink2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.cardSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, size: 16, color: p.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      style: TextStyle(fontSize: 13, color: p.ink),
                      cursorColor: p.accent,
                      onChanged: (String v) => setState(() => _q = v),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索分类',
                        hintStyle: TextStyle(fontSize: 12.5, color: p.ink3),
                      ),
                    ),
                  ),
                  if (_q.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _search.clear();
                        setState(() => _q = '');
                      },
                      child: Icon(Icons.cancel_rounded, size: 15, color: p.ink3),
                    ),
                ],
              ),
            ),
            if (showRecent) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Icon(Icons.history_rounded, size: 13, color: p.ink3),
                  const SizedBox(width: 4),
                  Text('最近使用',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.ink3)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recents.take(6).map((CategoryDef c) {
                  final bool on = c.id == widget.current;
                  return GestureDetector(
                    onTap: () => _choose(c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: on ? c.color.withOpacity(0.16) : c.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: on ? c.color.withOpacity(0.7) : c.color.withOpacity(0.18),
                          width: on ? 1.3 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(c.icon, size: 14, color: c.color),
                          const SizedBox(width: 5),
                          Text(c.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text('全部分类',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.ink3)),
                  const Spacer(),
                  if (_q.isNotEmpty)
                    Text('${filtered.length} 个结果',
                        style: TextStyle(fontSize: 10.5, color: p.ink3)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.search_off_rounded, size: 26, color: p.ink3),
                            const SizedBox(height: 8),
                            Text('没有找到分类',
                                style: TextStyle(fontSize: 12, color: p.ink3)),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 4,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext c, int i) {
                        final CategoryDef cat = filtered[i];
                        final bool on = cat.id == widget.current;
                        return GestureDetector(
                          onTap: () => _choose(cat),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cat.color.withOpacity(on ? 0.22 : 0.11),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: on ? cat.color : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(cat.icon, size: 19, color: cat.color),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cat.name,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                  color: on ? cat.color : p.ink2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
