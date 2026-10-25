import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';

/// 备注词云：字号随使用次数放大，颜色取自该备注最常用的分类，保证不同备注有区分度。
class NoteCloud extends StatelessWidget {
  const NoteCloud({
    Key? key,
    required this.data,
    required this.palette,
    required this.selected,
    required this.onTap,
    this.wrap = true,
    this.maxFont = 16.5,
    this.minFont = 11.5,
  }) : super(key: key);

  final List<NoteCloudItem> data;
  final Palette palette;
  final String selected;
  final ValueChanged<String> onTap;
  final bool wrap;
  final double maxFont;
  final double minFont;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final int maxCount =
        data.fold<int>(1, (int m, NoteCloudItem e) => e.count > m ? e.count : m);
    // 同一分类的多条备注用深浅阶梯区分，避免整片同色
    final Map<String, int> seen = <String, int>{};
    final List<Widget> chips = data.map((NoteCloudItem item) {
      final int idx = seen.update(item.catId, (int v) => v + 1, ifAbsent: () => 0);
      return _chip(item, maxCount, idx);
    }).toList();
    if (!wrap) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < chips.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 7),
            chips[i],
          ],
        ],
      );
    }
    return Wrap(spacing: 7, runSpacing: 8, children: chips);
  }

  Widget _chip(NoteCloudItem item, int maxCount, int shadeIndex) {
    final double ratio = maxCount <= 1 ? 0.35 : (item.count - 1) / (maxCount - 1);
    final double font = minFont + ratio * (maxFont - minFont);
    final bool on = selected == item.text;
    const List<double> shades = <double>[0, 0.14, 0.26, 0.36];
    final Color tintColor = catById(item.catId).color;
    final Color base =
        Color.lerp(tintColor, palette.ink, shades[shadeIndex % shades.length]) ?? tintColor;
    return GestureDetector(
      onTap: () => onTap(item.text),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10 + ratio * 4, vertical: 5 + ratio * 2),
        decoration: BoxDecoration(
          color: base.withOpacity(on ? 0.24 : 0.09 + ratio * 0.07 + (shadeIndex % 4) * 0.018),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: on ? base.withOpacity(0.85) : base.withOpacity(0.16),
            width: on ? 1.4 : 0.9,
          ),
        ),
        child: Text(
          item.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: font,
            height: 1.15,
            fontWeight: on || ratio > 0.6 ? FontWeight.w700 : FontWeight.w500,
            color: on ? base : Color.lerp(base, palette.ink, palette.dark ? 0.28 : 0.42),
          ),
        ),
      ),
    );
  }
}
