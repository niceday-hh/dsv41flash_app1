import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import 'whale_mark.dart';

/// 保存成功的鲸鱼水花：轻微上浮 + 一圈水波扩散，700ms 自动消失。
/// 不拦截触摸，失败时静默跳过。
class WhaleSplash {
  static void show(BuildContext context) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _Splash(onDone: () {
        if (entry.mounted) entry.remove();
      }),
    );
    overlay.insert(entry);
  }
}

class _Splash extends StatefulWidget {
  const _Splash({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext ctx, Widget? _) {
          final double t = Curves.easeOutCubic.transform(_c.value);
          final double fade = _c.value < 0.7 ? 1 : (1 - (_c.value - 0.7) / 0.3).clamp(0.0, 1.0);
          return Opacity(
            opacity: fade,
            child: Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // 水波
                    for (int i = 0; i < 3; i++)
                      Transform.scale(
                        scale: 0.4 + t * (1.0 + i * 0.55),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.accent.withOpacity((1 - t) * (0.32 - i * 0.08)),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    // 鲸鱼本体
                    Transform.translate(
                      offset: Offset(0, -14 * t),
                      child: Transform.scale(
                        scale: 0.72 + 0.36 * Curves.easeOutBack.transform(_c.value),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: p.gradient,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: p.accentGlow,
                          ),
                          alignment: Alignment.center,
                          child: const WhaleMark(size: 52, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
