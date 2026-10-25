import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
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

enum _Stage { preparing, ready, recording, recognizing, review, error }

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({Key? key}) : super(key: key);

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  late AnimationController _wave;
  late final TextEditingController _textCtrl;
  Timer? _ticker;
  Timer? _reparseDebounce;

  _Stage _stage = _Stage.preparing;
  String _message = '正在准备离线语音模型…';
  int _seconds = 0;
  double _level = 0;
  VoiceIntent? _intent;
  final Set<String> _edited = <String>{};
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _textCtrl.addListener(_onTextChanged);
    _boot();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _reparseDebounce?.cancel();
    _wave.dispose();
    _textCtrl.dispose();
    if (_holding) asr.AsrEngine.cancelCapture();
    super.dispose();
  }

  Future<void> _boot() async {
    if (!asr.AsrEngine.supported) {
      setState(() {
        _stage = _Stage.error;
        _message = '当前平台不支持离线语音，请在 Android 客户端使用';
      });
      return;
    }
    if (asr.AsrEngine.isReady) {
      setState(() {
        _stage = _Stage.ready;
        _message = '按住下方按钮说话';
      });
      return;
    }
    await asr.AsrEngine.warmUp();
    if (!mounted) return;
    if (asr.AsrEngine.isReady) {
      setState(() {
        _stage = _Stage.ready;
        _message = '按住下方按钮说话';
      });
    } else {
      setState(() {
        _stage = _Stage.error;
        _message = '模型加载失败，请重试';
      });
    }
  }

  // ---------------------------------------------------------------- 按住说话

  Future<void> _startHold() async {
    if (_stage == _Stage.preparing || _stage == _Stage.recognizing || _holding) return;
    HapticFeedback.mediumImpact();
    _holding = true;
    setState(() {
      _stage = _Stage.recording;
      _seconds = 0;
      _intent = null;
      _edited.clear();
      _textCtrl.clear();
      _message = '松手结束并识别';
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (Timer t) {
      if (!mounted) return;
      setState(() {
        _level = asr.AsrEngine.level;
        if (t.tick % 8 == 0) _seconds++;
      });
      if (_seconds >= 30) _endHold();
    });
    final bool ok = await asr.AsrEngine.startCapture();
    if (!ok && mounted) {
      _ticker?.cancel();
      _ticker = null;
      _holding = false;
      setState(() {
        _stage = _Stage.error;
        _message = '请允许麦克风权限，然后按住说话';
      });
    }
  }

  /// 把用户的历史备注喂给解析器，用于按自己的说法推荐分类
  List<NoteHint> _history() {
    final AppStore store = AppScope.storeOf(context);
    final List<NoteHint> out = <NoteHint>[];
    for (final bool exp in <bool>[true, false]) {
      for (final NoteStat n in store.noteStats(expense: exp)) {
        out.add(NoteHint(
          n.text,
          n.cats.isEmpty ? (exp ? 'other' : 'otherin') : n.cats.first,
          n.count,
        ));
      }
    }
    return out;
  }

  Future<void> _endHold() async {
    if (!_holding) return;
    _holding = false;
    _ticker?.cancel();
    _ticker = null;
    if (!mounted) return;
    setState(() {
      _stage = _Stage.recognizing;
      _message = '识别中…';
      _level = 0;
    });
    try {
      final String text = await asr.AsrEngine.stopAndRecognize();
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() {
          _stage = _Stage.ready;
          _message = '没听清，再试一次';
        });
        return;
      }
      _textCtrl.text = text;
      _textCtrl.selection = TextSelection.collapsed(offset: text.length);
      final VoiceIntent parsed = parseVoice(text, history: _history());
      setState(() {
        _intent = parsed;
        _stage = _Stage.review;
        _message = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.ready;
        _message = '识别失败，请重试';
      });
    }
  }

  Future<void> _cancelHold() async {
    if (!_holding) return;
    _holding = false;
    _ticker?.cancel();
    _ticker = null;
    await asr.AsrEngine.cancelCapture();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.ready;
      _level = 0;
      _message = '按住下方按钮说话';
    });
  }

  // ---------------------------------------------------------------- 编辑

  void _onTextChanged() {
    if (_stage != _Stage.review) return;
    _reparseDebounce?.cancel();
    _reparseDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted || _stage != _Stage.review) return;
      final VoiceIntent? prev = _intent;
      if (prev == null) return;
      final VoiceIntent next = parseVoice(_textCtrl.text, history: _history());
      setState(() {
        // 用户手动改过的字段不被重新解析覆盖
        _intent = next.copyWith(
          amount: _edited.contains('amount') ? prev.amount : null,
          catId: _edited.contains('category') ? prev.catId : null,
          date: _edited.contains('date') ? prev.date : null,
          expense: _edited.contains('type') ? prev.expense : null,
          note: _edited.contains('note') ? prev.note : null,
        );
      });
    });
  }

  Future<void> _pickCategory() async {
    final VoiceIntent? intent = _intent;
    if (intent == null) return;
    final Palette p = AppScope.paletteOf(context);
    final List<CategoryDef> cats =
        catsFor(intent.expense).where((CategoryDef c) => c.expense == intent.expense).toList();
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('选择分类', style: T.h2(p).copyWith(fontSize: 16)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.map((CategoryDef c) {
                final bool on = c.id == intent.catId;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, c.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: on ? c.color.withOpacity(0.16) : p.cardSoft,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: on ? c.color : Colors.transparent, width: 1.4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(c.icon, size: 15, color: c.color),
                        const SizedBox(width: 6),
                        Text(c.name,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _edited.add('category');
      _intent = _intent!.copyWith(catId: picked);
    });
  }

  Future<void> _pickDate() async {
    final VoiceIntent? intent = _intent;
    if (intent == null) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: intent.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _edited.add('date');
      _intent = _intent!.copyWith(date: picked);
    });
  }

  Future<void> _editAmount() async {
    final VoiceIntent? intent = _intent;
    if (intent == null) return;
    final TextEditingController c = TextEditingController(text: intent.amount.toStringAsFixed(2));
    final double? v = await showDialog<double>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('修改金额'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: '¥ '),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (v == null || v <= 0 || !mounted) return;
    setState(() {
      _edited.add('amount');
      _intent = _intent!.copyWith(amount: v);
    });
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            const SizedBox(height: 16),
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
                    Text('离线识别 · 数据不出手机',
                        style: TextStyle(fontSize: 10.5, color: p.ink3)),
                  ],
                ),
                const Spacer(),
                Pressable(
                  onTap: () async {
                    if (_holding) await _cancelHold();
                    if (mounted) Navigator.pop(context);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration:
                        BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(15)),
                    child: Icon(Icons.close_rounded, size: 16, color: p.ink2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _waveform(p),
            const SizedBox(height: 10),
            Text(
              _stage == _Stage.recording
                  ? '${_seconds.toString().padLeft(2, '0')}s / 30s'
                  : _message,
              style: TextStyle(
                fontSize: 11.5,
                color: _stage == _Stage.recording ? p.accent : p.ink3,
                fontWeight: _stage == _Stage.recording ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            if (_stage == _Stage.review) _review(p) else _holdButton(p),
            if (_stage == _Stage.review) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Pressable(
                      onTap: () {
                        setState(() {
                          _stage = _Stage.ready;
                          _intent = null;
                          _edited.clear();
                          _textCtrl.clear();
                          _message = '按住下方按钮说话';
                        });
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: p.cardSoft,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: Text('重说',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: p.ink2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Pressable(
                      onTap: () {
                        final VoiceIntent? intent = _intent;
                        if (intent == null || !intent.valid) return;
                        Navigator.pop(context, intent);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: p.gradient,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: p.accentGlow,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '填入账单',
                          style: TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _waveform(Palette p) {
    return AnimatedBuilder(
      animation: _wave,
      builder: (BuildContext context, Widget? child) {
        final bool active = _stage == _Stage.recording;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(28, (int i) {
            final double phase = math.sin((_wave.value * 2 * math.pi) + i * 0.55);
            final double amp = active ? (0.18 + _level * 1.8) : 0.10;
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
    );
  }

  Widget _holdButton(Palette p) {
    final bool busy = _stage == _Stage.preparing || _stage == _Stage.recognizing;
    final bool recording = _stage == _Stage.recording;
    return Listener(
      onPointerDown: (_) => _startHold(),
      onPointerUp: (_) => _endHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 62,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: busy ? null : p.gradient,
          color: busy ? p.cardSoft : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: busy ? null : p.accentGlow,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.ink3),
              )
            else
              Icon(
                recording ? Icons.stop_circle_outlined : Icons.mic_rounded,
                color: Colors.white,
                size: 21,
              ),
            const SizedBox(width: 9),
            Text(
              _stage == _Stage.preparing
                  ? '正在加载模型…'
                  : _stage == _Stage.recognizing
                      ? '识别中…'
                      : recording
                          ? '松手 识别'
                          : '按住 说话',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: busy ? p.ink3 : Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _review(Palette p) {
    final VoiceIntent intent = _intent!;
    final CategoryDef cat = catById(intent.catId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          decoration: BoxDecoration(
            color: p.cardSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _textCtrl,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(
                fontSize: 15, height: 1.5, color: p.ink, fontWeight: FontWeight.w600),
            cursorColor: p.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: '识别结果，可直接修改后自动重新拆分',
              hintStyle: TextStyle(fontSize: 12, color: p.ink3),
              suffixIcon: Icon(Icons.edit_rounded, size: 14, color: p.ink3),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            _chip(p, cat.name, cat.color, Icons.category_rounded, onTap: _pickCategory),
            const SizedBox(width: 8),
            _chip(
              p,
              '¥${intent.amount.toStringAsFixed(intent.amount == intent.amount.roundToDouble() ? 0 : 2)}',
              p.accent,
              Icons.payments_rounded,
              onTap: _editAmount,
            ),
            const SizedBox(width: 8),
            _chip(
              p,
              '${intent.date.month}月${intent.date.day}日',
              p.ink2,
              Icons.event_rounded,
              onTap: _pickDate,
            ),
          ],
        ),
        if (intent.note.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.sticky_note_2_outlined, size: 13, color: p.ink3),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  intent.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.ink2),
                ),
              ),
              Text(
                intent.expense ? '支出' : '收入',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: intent.expense ? p.expense : p.income,
                ),
              ),
            ],
          ),
        ],
        if (intent.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          for (final String w in intent.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, size: 12, color: p.expense),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(w, style: TextStyle(fontSize: 11, color: p.expense)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _chip(Palette p, String text, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
