import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'common.dart';

enum EntryChoice { manual, voice }

/// 底栏中间的「+」：轻点手动记账；按住上滑展开左右两个入口，
/// 拖到目标松手即进入，滑回中心或移出目标松手取消。
class EntryLauncher extends StatefulWidget {
  const EntryLauncher({
    Key? key,
    required this.onManual,
    required this.onVoice,
  }) : super(key: key);

  final VoidCallback onManual;
  final VoidCallback onVoice;

  @override
  State<EntryLauncher> createState() => _EntryLauncherState();
}

class _EntryLauncherState extends State<EntryLauncher> with SingleTickerProviderStateMixin {
  final GlobalKey _anchor = GlobalKey();
  final ValueNotifier<EntryChoice?> _selection = ValueNotifier<EntryChoice?>(null);
  late final AnimationController _anim;
  OverlayEntry? _entry;
  RenderBox? _overlayBox;
  Offset _origin = Offset.zero;
  Offset _down = Offset.zero;
  int? _pointer;
  bool _moved = false;
  bool _closing = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 110),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _selection.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    _overlayBox = null;
  }

  void _handleDown(PointerDownEvent e) {
    if (_pointer != null || _closing || _entry != null) return;
    _pointer = e.pointer;
    _down = e.position;
    _moved = false;
    setState(() => _pressed = true);
  }

  void _handleMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _closing) return;
    final Offset delta = e.position - _down;
    if (delta.distance > kTouchSlop) _moved = true;
    // 不做长按计时：向上移动超过 22px 立即展开
    if (_entry == null && delta.dy <= -22) {
      _open();
    }
    if (_entry != null) _track(e.position);
  }

  void _handleUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    if (_entry != null) {
      _track(e.position);
      final EntryChoice? choice = _selection.value;
      unawaited(_finish(choice));
      return;
    }
    final bool tapped = !_moved && (e.position - _down).distance <= kTouchSlop;
    _pointer = null;
    setState(() => _pressed = false);
    if (tapped) widget.onManual();
  }

  void _handleCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    setState(() => _pressed = false);
    if (_entry != null) unawaited(_finish(null));
  }

  void _open() {
    if (_entry != null || _closing) return;
    final RenderObject? anchor = _anchor.currentContext?.findRenderObject();
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final RenderObject? box = overlay.context.findRenderObject();
    if (anchor is! RenderBox || box is! RenderBox) return;
    _overlayBox = box;
    _origin = box.globalToLocal(anchor.localToGlobal(anchor.size.center(Offset.zero)));
    _selection.value = null;
    _entry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_entry!);
    _anim.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _track(Offset globalPosition) {
    final RenderBox? box = _overlayBox;
    if (box == null) return;
    final Offset point = box.globalToLocal(globalPosition);
    final Offset delta = point - _origin;
    EntryChoice? selected;

    // 中心留出取消区，避免轻微上滑就误选
    if (delta.distance > 44 && delta.dy < -48) {
      for (final EntryChoice c in EntryChoice.values) {
        final Offset target = _targetCenter(c);
        final double radius = 34 + (_selection.value == c ? 9 : 0);
        if ((point - target).distance <= radius) {
          selected = c;
          break;
        }
      }
    }
    if (selected == _selection.value) return;
    _selection.value = selected;
    if (selected != null) HapticFeedback.selectionClick();
  }

  Offset _targetCenter(EntryChoice c) {
    final double dx = c == EntryChoice.manual ? -86 : 86;
    return _origin + Offset(dx, -118);
  }

  Future<void> _finish(EntryChoice? choice) async {
    if (_closing) return;
    _closing = true;
    await _anim.reverse();
    _removeOverlay();
    _pointer = null;
    _closing = false;
    if (!mounted) return;
    setState(() => _pressed = false);
    if (choice == EntryChoice.manual) {
      widget.onManual();
    } else if (choice == EntryChoice.voice) {
      widget.onVoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleCancel,
      child: Center(
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 130),
          child: Container(
            key: _anchor,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: p.gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: p.accentGlow,
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 27),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final Palette p = AppScope.paletteOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_anim, _selection]),
      builder: (BuildContext ctx, Widget? _) {
        final double raw = _anim.value.clamp(0.0, 1.0);
        final double t = Curves.easeOutCubic.transform(raw);
        final double pop = Curves.easeOutBack.transform(raw);
        final Size screen = MediaQuery.of(context).size;
        final double cx = (_origin.dx / screen.width) * 2 - 1;
        final double cy = (_origin.dy / screen.height) * 2 - 1;

        return SizedBox(
          width: screen.width,
          height: screen.height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 以「+」为圆心的径向遮罩，视觉焦点收在按钮附近
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(cx, cy),
                      radius: 1.05,
                      colors: <Color>[
                        Colors.black.withOpacity(0.08 * t),
                        Colors.black.withOpacity(0.58 * t),
                      ],
                      stops: const <double>[0.0, 0.82],
                    ),
                  ),
                ),
              ),
              ...EntryChoice.values.map((EntryChoice c) => _target(p, c, t, pop)),
              // 操作提示
              Positioned(
                left: screen.width / 2 - 90,
                top: _origin.dy - 196,
                width: 180,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - t * 0.35).clamp(0.0, 1.0),
                    child: Text(
                      _selection.value == null ? '滑到目标后松手' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.92),
                        letterSpacing: 0.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _target(Palette p, EntryChoice c, double t, double pop) {
    final Offset target = _targetCenter(c);
    // 从「+」位置弹出到目标位置，带回弹
    final Offset pos = Offset.lerp(_origin, target, pop.clamp(0.0, 1.08))!;
    final bool on = _selection.value == c;
    final Color tint = c == EntryChoice.manual ? p.accent : p.accent2;
    final Color idleBg = p.dark ? const Color(0xFF232636) : Colors.white;
    final Color idleBorder = p.dark ? Colors.white.withOpacity(0.12) : Colors.white;
    final Color labelIdleBg = p.dark ? const Color(0xFF2A2E42) : Colors.white;

    return Positioned(
      left: pos.dx - 48,
      top: pos.dy - 31,
      width: 96,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              scale: on ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: on
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[tint, tint.withOpacity(0.78)],
                        )
                      : null,
                  color: on ? null : idleBg,
                  border: Border.all(
                    color: on ? Colors.white.withOpacity(0.34) : idleBorder,
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: on ? tint.withOpacity(0.45) : Colors.black.withOpacity(0.20),
                      blurRadius: on ? 26 : 18,
                      spreadRadius: on ? 2 : 0,
                      offset: Offset(0, on ? 12 : 9),
                    ),
                  ],
                ),
                child: Icon(
                  c == EntryChoice.manual ? Icons.edit_rounded : Icons.mic_rounded,
                  size: 24,
                  color: on ? Colors.white : tint,
                ),
              ),
            ),
            const SizedBox(height: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: on ? tint : labelIdleBg,
                borderRadius: BorderRadius.circular(9),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                c == EntryChoice.manual ? '手动记账' : '语音记账',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : (p.dark ? Colors.white : p.ink2),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
