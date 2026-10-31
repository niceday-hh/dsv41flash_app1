import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'asr_worker.dart';

abstract class ModelWorker {
  Future<void> prepare();
  Future<String> recognize(Float32List samples);
  void close();
}

/// Both extraction (Android executor) and inference (isolate) avoid the UI heap.
class LocalModelWorker implements ModelWorker {
  bool _closed = false;
  Isolate? _isolate;
  ReceivePort? _responses;
  SendPort? _commands;
  Completer<void>? _ready;
  final Map<int, Completer<String>> _pending = {};
  int _id = 0;
  @override
  Future<void> prepare() async {
    if (!Platform.isAndroid) throw StateError('请在 Android 客户端使用离线语音');
    final dir = await const MethodChannel('whale_ledger/asr').invokeMethod<String>('prepare');
    if (_closed) throw StateError('语音准备已取消');
    if (dir == null) throw StateError('离线模型缺失，请安装完整版本');
    final ready = _ready = Completer<void>();
    unawaited(ready.future.catchError((Object _) {}));
    final responses = _responses = ReceivePort();
    responses.listen((dynamic message) {
      final data = message as List;
      if (data[0] == 'ready') {
        _commands = data[1] as SendPort;
        if (!ready.isCompleted) ready.complete();
      } else if (data[0] == 'initError') {
        if (!ready.isCompleted) ready.completeError(StateError('${data[1]}'));
      } else {
        final c = _pending.remove(data[1] as int);
        if (data[0] == 'ok') { c?.complete('${data[2]}'); }
        else { c?.completeError(StateError('${data[2]}')); }
      }
    });
    final isolate = await Isolate.spawn(asrWorkerMain, <Object?>[responses.sendPort, dir], debugName: 'whale-asr');
    if (_closed) { isolate.kill(priority: Isolate.immediate); throw StateError('语音准备已取消'); }
    _isolate = isolate;
    await ready.future;
  }
  @override
  Future<String> recognize(Float32List samples) async {
    if (_closed || _commands == null) throw StateError('语音模型未就绪');
    final id = _id++, c = Completer<String>();
    _pending[id] = c;
    _commands!.send(<Object?>['recognize', id, samples]);
    try { return await c.future.timeout(const Duration(seconds: 40)); }
    finally { _pending.remove(id); }
  }
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.completeError(StateError('语音准备已取消'));
    for (final c in _pending.values) { if (!c.isCompleted) c.completeError(StateError('语音识别已取消')); }
    _pending.clear();
    _responses?.close(); _responses = null;
    _isolate?.kill(priority: Isolate.immediate); _isolate = null; _commands = null;
  }
}
