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
        final double t = Curves.easeOutCubic.transform(_anim.value.clamp(0.0, 1.0));
        final Size screen = MediaQuery.of(context).size;
        return SizedBox(
          width: screen.width,
          height: screen.height,
          child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withOpacity(0.46 * t)),
            ),
            ...EntryChoice.values.map((EntryChoice c) {
              final Offset center = _targetCenter(c);
              final bool on = _selection.value == c;
              return Positioned(
                left: center.dx - 36,
                top: center.dy - 36,
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * t,
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: on ? p.gradient : null,
                              color: on ? null : p.card,
                              border: Border.all(
                                color: on ? Colors.transparent : p.line,
                                width: 1.4,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withOpacity(on ? 0.22 : 0.12),
                                  blurRadius: on ? 22 : 12,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              c == EntryChoice.manual ? Icons.edit_rounded : Icons.mic_rounded,
                              size: 25,
                              color: on ? Colors.white : p.ink2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: on ? p.accent : Colors.black.withOpacity(0.46),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              c == EntryChoice.manual ? '手动记账' : '语音记账',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            Positioned(
              left: _origin.dx - 80,
              top: _origin.dy - 168,
              width: 160,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - t * 0.6).clamp(0.0, 1.0),
                  child: Center(
                    child: Text(
                      _selection.value == null ? '滑到目标松手' : '松手进入',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
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
}
