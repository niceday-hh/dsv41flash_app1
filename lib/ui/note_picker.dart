import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// 完整的备注选择器：常用 / 最近 / 全部 三档排序 + 搜索 + 仅本分类筛选。
Future<String?> showNotePicker(
  BuildContext context, {
  required AppStore store,
  required String catId,
  required bool expense,
  String initial = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _NotePickerSheet(
      store: store,
      catId: catId,
      expense: expense,
      initial: initial,
    ),
  );
}

class _NotePickerSheet extends StatefulWidget {
  const _NotePickerSheet({
    Key? key,
    required this.store,
    required this.catId,
    required this.expense,
    required this.initial,
  }) : super(key: key);

  final AppStore store;
  final String catId;
  final bool expense;
  final String initial;

  @override
  State<_NotePickerSheet> createState() => _NotePickerSheetState();
}

class _NotePickerSheetState extends State<_NotePickerSheet> {
  late final TextEditingController _draft;
  final TextEditingController _search = TextEditingController();
  late List<NoteStat> _all;
  int _tab = 0; // 0 常用 1 最近 2 全部
  bool _onlyCat = true;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.initial);
    _all = widget.store.noteStats(expense: widget.expense);
  }

  @override
  void dispose() {
    _draft.dispose();
    _search.dispose();
    super.dispose();
  }

  List<NoteStat> _visible() {
    final String q = _search.text.trim().toLowerCase();
    List<NoteStat> list = _all.where((NoteStat n) {
      if (_onlyCat && !n.cats.contains(widget.catId)) return false;
      if (q.isNotEmpty && !n.text.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    switch (_tab) {
      case 0:
        list.sort((NoteStat a, NoteStat b) {
          final int c = b.count.compareTo(a.count);
          return c != 0 ? c : a.text.compareTo(b.text);
        });
        break;
      case 1:
        list.sort((NoteStat a, NoteStat b) {
          final int c = b.latest.compareTo(a.latest);
          return c != 0 ? c : a.text.compareTo(b.text);
        });
        break;
      default:
        list.sort((NoteStat a, NoteStat b) => a.text.compareTo(b.text));
    }
    return list;
  }

  void _pick(String text) {
    HapticFeedback.selectionClick();
    _draft.text = text;
    _draft.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final List<NoteStat> list = _visible();
    final int total = _all.length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration:
                    BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: <Widget>[
                  Text('选个备注', style: T.h2(p).copyWith(fontSize: 17)),
                  const SizedBox(width: 8),
                  Text('$total 条历史', style: TextStyle(fontSize: 11, color: p.ink3)),
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: p.cardSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search_rounded, size: 17, color: p.ink3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        style: TextStyle(fontSize: 13.5, color: p.ink),
                        cursorColor: p.accent,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '搜索历史备注',
                          hintStyle: TextStyle(fontSize: 13, color: p.ink3),
                        ),
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() {});
                        },
                        child: Icon(Icons.cancel_rounded, size: 15, color: p.ink3),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: <Widget>[
                  Segmented(
                    labels: const <String>['常用', '最近', '全部'],
                    index: _tab,
                    compact: true,
                    segWidth: 52,
                    onChanged: (int i) {
                      HapticFeedback.selectionClick();
                      setState(() => _tab = i);
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _onlyCat = !_onlyCat);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _onlyCat ? p.accent.withOpacity(0.12) : p.cardSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _onlyCat ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 12,
                            color: _onlyCat ? p.accent : p.ink3,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '仅${catById(widget.catId).name}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _onlyCat ? p.accent : p.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        total == 0 ? '还没有历史备注，在下方直接填写' : '没有匹配的备注，换个词试试',
                        style: TextStyle(fontSize: 12.5, color: p.ink3),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      itemCount: list.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        final NoteStat n = list[i];
                        final bool on = _draft.text == n.text;
                        return GestureDetector(
                          onTap: () => _pick(n.text),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: p.line.withOpacity(0.6), width: 0.7),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  on
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 16,
                                  color: on ? p.accent : p.ink3.withOpacity(0.6),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    n.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: p.ink,
                                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (n.cats.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      n.cats.map((String id) => catById(id).name).take(2).join('·'),
                                      style: TextStyle(fontSize: 10, color: p.ink3),
                                    ),
                                  ),
                                Text('${n.count} 次', style: TextStyle(fontSize: 11, color: p.ink3)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              child: Column(
                children: <Widget>[
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: p.cardSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_rounded, size: 15, color: p.ink3),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _draft,
                            style: TextStyle(fontSize: 14, color: p.ink),
                            cursorColor: p.accent,
                            maxLength: 20,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              hintText: '也可以直接写新的',
                              hintStyle: TextStyle(fontSize: 13, color: p.ink3),
                            ),
                          ),
                        ),
                        if (_draft.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _pick(''),
                            child: Icon(Icons.cancel_rounded, size: 15, color: p.ink3),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Pressable(
                      onTap: () => Navigator.pop(context, _draft.text.trim()),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: p.gradient,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: p.accentGlow,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _draft.text.trim().isEmpty ? '保存空备注' : '使用「${_draft.text.trim()}」',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
