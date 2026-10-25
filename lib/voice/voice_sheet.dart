import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../theme.dart';
import '../ui/common.dart';
import 'asr_engine.dart' as asr;
import 'voice_parser.dart';

/// 打开语音记账面板，返回解析结果（null 表示取消）
Future<VoiceIntent?> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<VoiceIntent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (BuildContext ctx) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({Key? key}) : super(key: key);

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  late AnimationController _wave;
  asr.AsrEngine? _engine;
  String _text = '';
  String _status = '正在准备离线语音模型…';
  bool _listening = false;
  bool _ready = false;
  double _level = 0;
  VoiceIntent? _intent;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _boot();
  }

  @override
  void dispose() {
    _wave.dispose();
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (!asr.AsrEngine.supported) {
      setState(() => _status = '当前平台不支持离线语音，请在 Android 上使用');
      return;
    }
    final asr.AsrEngine? engine = await asr.AsrEngine.create();
    if (!mounted) return;
    if (engine == null) {
      setState(() => _status = '模型加载失败，请重试');
      return;
    }
    _engine = engine;
    setState(() {
      _ready = true;
      _status = '已就绪，开始说话';
    });
    await _listen();
  }

  Future<void> _listen() async {
    final asr.AsrEngine? engine = _engine;
    if (engine == null) return;
    setState(() {
      _text = '';
      _intent = null;
      _listening = true;
      _status = '正在聆听…';
    });
    try {
      await engine.start(
        onPartial: (String partial) {
          if (!mounted) return;
          setState(() {
            _text = partial;
            _intent = parseVoice(partial);
          });
        },
        onLevel: (double level) {
          if (mounted) setState(() => _level = level);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _status = '麦克风不可用，请检查权限');
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final asr.AsrEngine? engine = _engine;
    String finalText = _text;
    if (engine != null) {
      final String t = await engine.stop();
      if (t.isNotEmpty) finalText = t;
    }
    if (!mounted) return;
    final VoiceIntent intent = parseVoice(finalText);
    if (!intent.valid) {
      setState(() {
        _listening = false;
        _status = '没有听清金额，请说“午饭二十八块”这样';
        _text = finalText;
      });
      return;
    }
    Navigator.of(context).pop(intent);
  }

  Future<void> _restart() async {
    final asr.AsrEngine? engine = _engine;
    if (engine != null) await engine.stop();
    await _listen();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final VoiceIntent? intent = _intent;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: p.gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: p.accentGlow,
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('语音记账', style: T.h2(p).copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('离线识别 · 数据不出手机', style: TextStyle(fontSize: 10.5, color: p.ink3)),
                  ],
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(15)),
                    child: Icon(Icons.close_rounded, size: 16, color: p.ink2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _wave,
              builder: (BuildContext context, Widget? child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(28, (int i) {
                    final double phase = math.sin((_wave.value * 2 * math.pi) + i * 0.55);
                    final double amp = _listening ? (0.18 + _level * 1.6) : 0.12;
                    final double h = (14 + 26 * (0.5 + 0.5 * phase) * amp).clamp(6.0, 48.0);
                    return Container(
                      width: 5,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 2.2),
                      decoration: BoxDecoration(
                        gradient: p.gradient,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.cardSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _text.isEmpty ? _status : _text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _text.isEmpty ? 12 : 15,
                  height: 1.5,
                  color: _text.isEmpty ? p.ink3 : p.ink,
                  fontWeight: _text.isEmpty ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
            if (intent != null && intent.valid) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  _chip(p, catById(intent.catId).name, catById(intent.catId).color),
                  const SizedBox(width: 8),
                  _chip(p, '¥${intent.amount.toStringAsFixed(intent.amount == intent.amount.roundToDouble() ? 0 : 2)}', p.accent),
                  const SizedBox(width: 8),
                  Flexible(child: _chip(p, intent.note, p.ink2)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: Pressable(
                    onTap: _ready ? _restart : null,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: p.cardSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.refresh_rounded, size: 17, color: p.ink2),
                          const SizedBox(width: 6),
                          Text('重说', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink2)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Pressable(
                    onTap: _ready ? _finish : null,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: p.gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: p.accentGlow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _listening ? '说完了，填入账单' : '填入账单',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(Palette p, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
