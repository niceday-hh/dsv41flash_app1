import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'whale_mark.dart';

/// 全局状态作用域
class AppScope extends InheritedNotifier<AppStore> {
  final Palette palette;

  const AppScope({
    Key? key,
    required this.palette,
    required AppStore store,
    required Widget child,
  }) : super(key: key, notifier: store, child: child);

  static AppStore storeOf(BuildContext c) {
    final AppScope? s = c.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope not found');
    return s!.notifier!;
  }

  static Palette paletteOf(BuildContext c) {
    final AppScope? s = c.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope not found');
    return s!.palette;
  }
}

/// 判断 Context 是否仍挂载（兼容旧版 Flutter 无 context.mounted）
bool ctxMounted(BuildContext c) {
  if (c is! Element) return false;
  return c.owner != null;
}

// ------------------------------------------------------------------ 格式化

String fmtMoney(num v, {int decimals = 2, bool trimZero = false}) {
  final String s = v.abs().toStringAsFixed(decimals);
  final List<String> parts = s.split('.');
  final String intPart = parts[0];
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  String frac = decimals > 0 ? '.${parts[1]}' : '';
  if (trimZero && frac.endsWith('00')) frac = '';
  return '${v < 0 ? '-' : ''}$buf$frac';
}

String fmtAmount(num v) {
  if (v == v.roundToDouble()) return fmtMoney(v, decimals: 0);
  return fmtMoney(v, decimals: 2);
}

const List<String> _week = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayCn(DateTime d) => _week[d.weekday - 1];

String dayLabel(DateTime d) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime target = DateTime(d.year, d.month, d.day);
  final int diff = today.difference(target).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  return '${d.month}月${d.day}日';
}

String monthLabel(DateTime m) => '${m.year}年${m.month}月';

String timeLabel(DateTime d) {
  final String h = d.hour.toString().padLeft(2, '0');
  final String mi = d.minute.toString().padLeft(2, '0');
  return '$h:$mi';
}

// ------------------------------------------------------------------ 基础组件

/// 按下缩放反馈（iOS 触感）
class Pressable extends StatefulWidget {
  final Widget? child;

  /// 需要按压态自绘（例如键盘按键按下时加深底色）时使用，
  /// 传入后优先于 [child]。
  final Widget Function(bool down)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool tapEnabled;

  /// 下压 / 回弹时长。快速点击时下压要够快，回弹可以慢一点更跟手。
  final int downMs;
  final int upMs;

  /// 抬起后保持按压态的最短时间。
  /// 普通点击只有 60~100ms，若立刻回弹，3% 的缩放几乎看不见。
  final int holdMs;

  const Pressable({
    Key? key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.tapEnabled = true,
    this.downMs = 70,
    this.upMs = 150,
    this.holdMs = 70,
  }) : super(key: key);

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Timer? _release;

  void _set(bool v) {
    if (!mounted || _down == v) return;
    setState(() => _down = v);
  }

  void _press() {
    _release?.cancel();
    _set(true);
  }

  void _unpress() {
    _release?.cancel();
    if (!_down) return;
    if (widget.holdMs <= 0) {
      _set(false);
      return;
    }
    _release = Timer(Duration(milliseconds: widget.holdMs), () => _set(false));
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget scaled = AnimatedScale(
      scale: _down ? widget.scale : 1.0,
      duration: Duration(milliseconds: _down ? widget.downMs : widget.upMs),
      curve: _down ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.builder?.call(_down) ?? widget.child,
    );

    // 关键：按压态用 Listener 而不是 GestureDetector.onTapDown。
    // onTapDown 要等手势竞技场判定（约 100ms），快速点击时
    // down/up 会落在同一帧，缩放动画根本没机会开始——看起来就是「按了没反应」。
    // Listener 在 pointerdown 当帧就能响应，和系统按钮手感一致。
    return Listener(
      onPointerDown: widget.tapEnabled ? (_) => _press() : null,
      onPointerUp: widget.tapEnabled ? (_) => _unpress() : null,
      onPointerCancel: widget.tapEnabled ? (_) => _unpress() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: scaled,
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Border? border;

  const SoftCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = R.xl,
    this.color,
    this.gradient,
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? p.hairline,
        boxShadow: p.shadow,
      ),
      child: child,
    );
    if (onTap != null) {
      box = Pressable(onTap: onTap, scale: 0.985, child: box);
    }
    return box;
  }
}

/// 章节标题
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionTitle(
      {Key? key,
      required this.title,
      this.action,
      this.onAction,
      this.trailing})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: <Widget>[
          Text(title,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  letterSpacing: -0.2)),
          const Spacer(),
          if (trailing != null) trailing!,
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: <Widget>[
                  Text(action!,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.ink2)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: p.ink3),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 分类图标气泡
class CatBubble extends StatelessWidget {
  final CategoryDef cat;
  final double size;
  final double iconSize;
  final bool solid;

  const CatBubble(
      {Key? key,
      required this.cat,
      this.size = 42,
      this.iconSize = 20,
      this.solid = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final Color tone = cat.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? tone : tone.withOpacity(p.dark ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(cat.icon, size: iconSize, color: solid ? Colors.white : tone),
    );
  }
}

/// 数字滚动
class AnimatedMoney extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final Duration duration;

  const AnimatedMoney({
    Key? key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 700),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (AppScope.storeOf(context).hideAmounts) {
      return Text('$prefix••••', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? _) {
        return Text('$prefix${fmtMoney(v)}', style: style);
      },
    );
  }
}

/// iOS 风格分段控件
class Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool compact;
  final double segWidth;

  const Segmented({
    Key? key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.compact = false,
    this.segWidth = 54,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final double h = compact ? 32 : 36;
    final double totalW = segWidth * labels.length;
    final double cellW = (totalW - 6) / labels.length;

    return Container(
      width: totalW,
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:
            p.dark ? Colors.white.withOpacity(0.075) : const Color(0xFFE7E9F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: labels.length <= 1
                ? Alignment.center
                : Alignment(-1 + 2 * index / (labels.length - 1), 0),
            child: Container(
              width: cellW,
              height: h - 6,
              decoration: BoxDecoration(
                color: p.dark ? const Color(0xFF2C2F42) : Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(p.dark ? 0.32 : 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: List<Widget>.generate(labels.length, (int i) {
              final bool active = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? p.ink : p.ink2,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 玻璃质感容器（磨砂）
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;

  const GlassPanel({
    Key? key,
    required this.child,
    this.radius = 28,
    this.padding,
    this.blur = 22,
    this.opacity = 0.76,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.dark
            ? Color.lerp(
                    const Color(0xFF151723), const Color(0xFF1B1E2C), opacity)!
                .withOpacity(opacity + 0.14)
            : Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: p.dark
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.85),
          width: 1.2,
        ),
      ),
      child: child,
    );
    // blur <= 0 时不挂 BackdropFilter：几乎不透明时磨砂看不出来，
    // 但模糊是每帧都要重新采样背景的，滚动时会实打实掉帧。
    if (blur <= 0)
      return ClipRRect(
          borderRadius: BorderRadius.circular(radius), child: panel);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      ),
    );
  }
}

/// 轻量 toast
void showToast(BuildContext context, String msg,
    {IconData icon = Icons.check_circle_rounded}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(milliseconds: 1600),
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 96),
      padding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1E2A).withOpacity(0.94),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                msg,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 空状态占位
class EmptyState extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;

  /// 默认用品牌鲸鱼替代通用图标
  final bool whaleMark;

  const EmptyState({
    Key? key,
    required this.title,
    required this.desc,
    this.icon = Icons.receipt_long_rounded,
    this.whaleMark = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: <Widget>[
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  p.accent.withOpacity(0.16),
                  p.accent2.withOpacity(0.10)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(R.l),
            ),
            alignment: Alignment.center,
            child: whaleMark
                ? WhaleMark(
                    size: 44,
                    color: p.accent,
                    eyeColor: p.accent,
                    sprayColor: p.accent)
                : Icon(icon, color: p.accent, size: 30),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text(desc,
              style: TextStyle(fontSize: 12.5, color: p.ink2),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
