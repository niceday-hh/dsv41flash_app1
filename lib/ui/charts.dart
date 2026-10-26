import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'common.dart';

class DonutSlice {
  final double value;
  final Color color;
  final String label;

  const DonutSlice(this.value, this.color, this.label);
}

/// 环形占比图（带动画与点击选中）
class DonutChart extends StatefulWidget {
  final List<DonutSlice> slices;
  final double size;
  final double stroke;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? center;

  const DonutChart({
    Key? key,
    required this.slices,
    this.size = 200,
    this.stroke = 20,
    this.selected = -1,
    required this.onSelect,
    this.center,
  }) : super(key: key);

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..forward();
  }

  @override
  void didUpdateWidget(covariant DonutChart old) {
    super.didUpdateWidget(old);
    if (old.slices.length != widget.slices.length) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details) {
    final double total = widget.slices.fold<double>(0, (double s, DonutSlice e) => s + e.value);
    if (total <= 0) return;
    final Offset local = details.localPosition;
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    final double dx = local.dx - center.dx;
    final double dy = local.dy - center.dy;
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    double acc = 0;
    for (int i = 0; i < widget.slices.length; i++) {
      final double sweep = widget.slices[i].value / total * math.pi * 2;
      if (angle >= acc && angle < acc + sweep) {
        widget.onSelect(widget.selected == i ? -1 : i);
        return;
      }
      acc += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: _c,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  size: Size.square(widget.size),
                  painter: _DonutPainter(
                    slices: widget.slices,
                    progress: Curves.easeOutCubic.transform(_c.value),
                    stroke: widget.stroke,
                    selected: widget.selected,
                  ),
                );
              },
            ),
            if (widget.center != null) widget.center!,
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double progress;
  final double stroke;
  final int selected;

  _DonutPainter({required this.slices, required this.progress, required this.stroke, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = slices.fold<double>(0, (double s, DonutSlice e) => s + e.value);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - stroke) / 2;

    final Paint bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.withOpacity(0.10)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    if (total <= 0) return;

    const double gap = 0.055;
    double start = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final DonutSlice s = slices[i];
      final double full = s.value / total * math.pi * 2;
      double sweep = (full - gap) * progress;
      if (sweep < 0) sweep = 0;
      final bool isSel = i == selected;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? stroke + 6 : stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color.withOpacity(selected == -1 || isSel ? 1 : 0.30);
      if (isSel) {
        canvas.drawCircle(center, radius, Paint()..color = s.color.withOpacity(0.0));
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        sweep,
        false,
        paint,
      );
      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.selected != selected || old.slices != slices;
}

/// 月度趋势柱状图
class TrendBars extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final double height;
  final int highlight;
  final ValueChanged<int>? onTap;

  const TrendBars({
    Key? key,
    required this.values,
    required this.labels,
    this.height = 132,
    this.highlight = -1,
    this.onTap,
  }) : super(key: key);

  @override
  State<TrendBars> createState() => _TrendBarsState();
}

class _TrendBarsState extends State<TrendBars> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  }

  @override
  void didUpdateWidget(covariant TrendBars old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final double maxV = widget.values.isEmpty
        ? 1
        : widget.values.reduce((double a, double b) => a > b ? a : b).clamp(1, double.infinity);

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(widget.values.length, (int i) {
              final double t = Curves.easeOutCubic
                  .transform(((_c.value - i * 0.055) / 0.62).clamp(0.0, 1.0));
              final double h = (widget.values[i] / maxV) * (widget.height - 46) * t;
              final bool hot = i == widget.highlight;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          widget.onTap!(i);
                        },
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        widget.values[i] <= 0 ? '' : _short(widget.values[i]),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: hot ? p.ink : p.ink2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FractionallySizedBox(
                        widthFactor: 0.62,
                        child: Container(
                        height: h < 4 ? 5 : h,
                        decoration: BoxDecoration(
                          gradient: hot ? p.gradient : null,
                          color: hot ? null : p.accent.withOpacity(p.dark ? 0.28 : 0.16),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: hot
                              ? <BoxShadow>[
                                  BoxShadow(color: p.accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6)),
                                ]
                              : null,
                        ),
                      ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: hot ? FontWeight.w700 : FontWeight.w500,
                          color: hot ? p.ink : p.ink2,
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  static String _short(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

/// 预算环形进度
class RingProgress extends StatelessWidget {
  final double progress; // 0..1+
  final double size;
  final double stroke;
  final Widget? center;
  final bool warn;

  const RingProgress({
    Key? key,
    required this.progress,
    this.size = 200,
    this.stroke = 18,
    this.center,
    this.warn = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: v,
                  stroke: stroke,
                  color: warn ? p.expense : p.accent,
                  color2: warn ? const Color(0xFFFF9A6C) : p.accent2,
                  track: p.dark ? Colors.white.withOpacity(0.07) : const Color(0xFFEDEEF6),
                ),
              ),
              if (center != null) center!,
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Color color;
  final Color color2;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.color2,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - stroke) / 2;
    final Paint bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, bg);

    if (progress <= 0) return;

    // 分段绘制渐变环（避免使用 canvas shader，保证 Web / 移动端一致）
    final double sweepTotal = math.pi * 2 * progress;
    const int segments = 90;
    final double seg = sweepTotal / segments;
    final Paint segPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    for (int i = 0; i < segments; i++) {
      final double t = i / (segments - 1 == 0 ? 1 : segments - 1);
      segPaint.color = Color.lerp(color, color2, t)!;
      final double a0 = -math.pi / 2 + seg * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a0,
        seg * 1.25,
        false,
        segPaint,
      );
    }

    // 起止端点圆头
    final Paint capPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius),
      stroke / 2,
      capPaint,
    );
    final double ang = -math.pi / 2 + sweepTotal;
    final Offset dot = Offset(center.dx + radius * math.cos(ang), center.dy + radius * math.sin(ang));
    canvas.drawCircle(dot, stroke / 2, Paint()..color = color2);
    canvas.drawCircle(dot, stroke * 0.30, Paint()..color = Colors.white.withOpacity(0.92));
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

/// 折线趋势图：渐变面积 + 网格 + 空心节点，点按可选中某个节点。
class TrendLine extends StatefulWidget {
  const TrendLine({
    Key? key,
    required this.values,
    required this.labels,
    this.height = 150,
    this.highlight = -1,
    this.onTap,
    required this.color,
    this.todayIndex = -1,
    this.todayColor,
  }) : super(key: key);

  final List<double> values;
  final List<String> labels;
  final double height;
  final int highlight;
  final ValueChanged<int>? onTap;
  final Color color;

  /// 当前周期里「今天」对应的节点下标，-1 表示不在本周期
  final int todayIndex;
  final Color? todayColor;

  @override
  State<TrendLine> createState() => _TrendLineState();
}

class _TrendLineState extends State<TrendLine> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620))..forward();
  }

  @override
  void didUpdateWidget(covariant TrendLine old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails d, double width, double height) {
    final int n = widget.values.length;
    if (n == 0 || widget.onTap == null) return;
    const double padX = 10;
    final double usable = width - padX * 2;
    final double step = n <= 1 ? 0 : usable / (n - 1);
    final int idx = step <= 0 ? 0 : ((d.localPosition.dx - padX) / step).round().clamp(0, n - 1);
    widget.onTap!(idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints cons) {
      final double w = cons.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails d) => _handleTap(d, w, widget.height),
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext c, Widget? child) => CustomPaint(
              painter: _TrendLinePainter(
                values: widget.values,
                labels: widget.labels,
                progress: Curves.easeOutCubic.transform(_c.value),
                highlight: widget.highlight,
                color: widget.color,
                todayIndex: widget.todayIndex,
                todayColor: widget.todayColor ?? widget.color,
                textColor: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                gridColor: widget.color.withOpacity(0.10),
              ),
              size: Size(w, widget.height),
            ),
          ),
        ),
      );
    });
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter({
    required this.values,
    required this.labels,
    required this.progress,
    required this.highlight,
    required this.color,
    required this.todayIndex,
    required this.todayColor,
    required this.textColor,
    required this.gridColor,
  });

  final List<double> values;
  final List<String> labels;
  final double progress;
  final int highlight;
  final Color color;
  final int todayIndex;
  final Color todayColor;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const double padL = 10;
    const double padR = 10;
    const double padTop = 14;
    const double padBottom = 24;
    final double w = size.width - padL - padR;
    final double h = size.height - padTop - padBottom;
    final double maxV = values.fold<double>(0, (double m, double v) => v > m ? v : m);
    final double top = maxV <= 0 ? 1 : maxV;

    // 网格
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = padTop + h * i / 3;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), grid);
    }

    final int n = values.length;
    final double step = n <= 1 ? 0 : w / (n - 1);
    double xOf(int i) => padL + step * i;
    double yOf(int i) => padTop + h - (values[i] / top) * h;

    final int shown = (n * progress).ceil().clamp(1, n);

    final Path line = Path();
    for (int i = 0; i < shown; i++) {
      final Offset p = Offset(xOf(i), yOf(i));
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }

    // 面积
    final Path area = Path.from(line)
      ..lineTo(xOf(shown - 1), padTop + h)
      ..lineTo(xOf(0), padTop + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[color.withOpacity(0.22), color.withOpacity(0.01)],
        ).createShader(Rect.fromLTWH(padL, padTop, w, h)),
    );

    // 峰值参考线
    if (maxV > 0) {
      final int peakIndex = values.indexOf(maxV);
      final double py = yOf(peakIndex);
      _dash(canvas, Offset(padL, py), Offset(padL + w, py), color.withOpacity(0.30), vertical: false);
      final TextPainter peakText = TextPainter(
        text: TextSpan(
          text: '峰值 ¥${_compact(maxV)}',
          style: TextStyle(fontSize: 9, height: 1.1, color: color, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // 峰值标签固定在左上角，避免和「今天」标签重叠
      peakText.paint(canvas, Offset(padL + 2, 2));
    }

    // 今日竖虚线
    if (todayIndex >= 0 && todayIndex < n) {
      final double tx = xOf(todayIndex);
      _dash(canvas, Offset(tx, padTop), Offset(tx, padTop + h), todayColor.withOpacity(0.45),
          vertical: true);
      final TextPainter todayText = TextPainter(
        text: TextSpan(
          text: '今天',
          style: TextStyle(fontSize: 9, height: 1.1, color: todayColor, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double dx = (tx - todayText.width / 2).clamp(0.0, size.width - todayText.width - 6);
      final RRect chip = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 4, 1, todayText.width + 8, 13),
        const Radius.circular(6),
      );
      canvas.drawRRect(chip, Paint()..color = todayColor.withOpacity(0.12));
      todayText.paint(canvas, Offset(dx, 2.5));
    }

    // 折线
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 节点（数量多时只画高点与选中点）
    final bool dense = n > 12;
    for (int i = 0; i < shown; i++) {
      final bool on = i == highlight;
      if (dense && !on && values[i] <= 0) continue;
      if (dense && !on && i != 0 && i != shown - 1) {
        // 密集时只保留每 1/6 的节点
        if (i % (n / 6).ceil() != 0) continue;
      }
      final Offset p = Offset(xOf(i), yOf(i));
      if (on) {
        canvas.drawLine(
          Offset(p.dx, padTop),
          Offset(p.dx, padTop + h),
          Paint()
            ..color = color.withOpacity(0.25)
            ..strokeWidth = 1.2,
        );
        canvas.drawCircle(p, 7, Paint()..color = color.withOpacity(0.18));
        canvas.drawCircle(p, 4.2, Paint()..color = color);
        canvas.drawCircle(p, 4.2, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
      } else {
        canvas.drawCircle(p, 3, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = color.withOpacity(0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // 标签（抽稀）
    final int stride = n <= 7 ? 1 : (n <= 12 ? 2 : (n / 6).ceil());
    for (int i = 0; i < n; i += stride) {
      final String label = i < labels.length ? labels[i] : '';
      if (label.isEmpty) continue;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 9.5, color: textColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      double dx = xOf(i) - tp.width / 2;
      dx = dx.clamp(0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - padBottom + 8));
    }
  }

  void _dash(Canvas canvas, Offset from, Offset to, Color color, {required bool vertical}) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    if (vertical) {
      for (double y = from.dy; y < to.dy; y += 6) {
        canvas.drawLine(Offset(from.dx, y), Offset(from.dx, (y + 3.2).clamp(from.dy, to.dy)), paint);
      }
    } else {
      for (double x = from.dx; x < to.dx; x += 6) {
        canvas.drawLine(Offset(x, from.dy), Offset((x + 3.2).clamp(from.dx, to.dx), to.dy), paint);
      }
    }
  }

  String _compact(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)} 万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter old) =>
      old.progress != progress ||
      old.highlight != highlight ||
      old.values != values ||
      old.color != color ||
      old.todayIndex != todayIndex;
}
