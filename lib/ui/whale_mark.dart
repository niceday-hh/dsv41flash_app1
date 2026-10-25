import 'package:flutter/material.dart';

/// 鲸鱼标志：与 Android 启动图标同源，1024 视口内手绘，任意尺寸都不糊。
class WhaleMark extends StatelessWidget {
  const WhaleMark({
    Key? key,
    required this.size,
    this.color = Colors.white,
    this.eyeColor,
    this.sprayColor,
    this.bellyColor,
  }) : super(key: key);

  final double size;
  final Color color;

  /// 眼睛颜色，默认取 [color] 加深
  final Color? eyeColor;

  /// 喷水水珠颜色
  final Color? sprayColor;

  /// 腹部弧线颜色
  final Color? bellyColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhalePainter(
          color: color,
          eyeColor: eyeColor,
          sprayColor: sprayColor,
          bellyColor: bellyColor,
        ),
      ),
    );
  }
}

class _WhalePainter extends CustomPainter {
  _WhalePainter({required this.color, this.eyeColor, this.sprayColor, this.bellyColor});

  final Color color;
  final Color? eyeColor;
  final Color? sprayColor;
  final Color? bellyColor;

  static final Path _tail = Path()
    ..moveTo(600, 610)
    ..cubicTo(660, 560, 720, 470, 790, 412)
    ..cubicTo(806, 402, 824, 414, 818, 434)
    ..cubicTo(796, 508, 776, 552, 760, 590)
    ..cubicTo(786, 616, 806, 660, 812, 716)
    ..cubicTo(816, 742, 792, 754, 772, 736)
    ..cubicTo(712, 682, 660, 646, 606, 624)
    ..close();

  static final Path _body = Path()
    ..moveTo(196, 566)
    ..cubicTo(196, 452, 292, 382, 414, 382)
    ..cubicTo(540, 382, 626, 456, 668, 560)
    ..cubicTo(690, 614, 662, 668, 596, 696)
    ..cubicTo(500, 736, 340, 730, 262, 686)
    ..cubicTo(216, 660, 196, 616, 196, 566)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 1024;
    canvas.save();
    canvas.scale(s);
    final Color dark = Color.lerp(color, const Color(0xFF1B1E45), 0.55)!;

    // 投影
    canvas.save();
    canvas.translate(6, 14);
    canvas.drawPath(_tail, Paint()..color = dark.withOpacity(0.13));
    canvas.drawPath(_body, Paint()..color = dark.withOpacity(0.13));
    canvas.restore();

    // 尾巴 + 胸鳍 + 身体
    canvas.drawPath(_tail, Paint()..color = color);
    canvas.save();
    canvas.translate(470, 690);
    canvas.rotate(-16 * 3.14159265 / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 172, height: 84),
      Paint()..color = color,
    );
    canvas.restore();
    canvas.drawPath(_body, Paint()..color = color);

    // 腹部弧线
    final Path belly = Path()
      ..moveTo(266, 632)
      ..quadraticBezierTo(420, 690, 586, 646);
    canvas.drawPath(
      belly,
      Paint()
        ..color = bellyColor ?? Color.lerp(color, const Color(0xFF6E7BF2), 0.45)!.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // 眼睛
    canvas.drawCircle(Offset(318, 520), 17, Paint()..color = eyeColor ?? const Color(0xFF5B5BD6));
    canvas.drawCircle(
      const Offset(313, 514),
      5,
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    // 喷水
    final Color dropColor = sprayColor ?? color;
    canvas.drawCircle(const Offset(300, 322), 16, Paint()..color = dropColor.withOpacity(0.92));
    canvas.drawCircle(const Offset(352, 272), 11, Paint()..color = dropColor.withOpacity(0.78));
    canvas.drawCircle(const Offset(262, 268), 8, Paint()..color = dropColor.withOpacity(0.58));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WhalePainter old) =>
      old.color != color || old.eyeColor != eyeColor || old.sprayColor != sprayColor;
}
