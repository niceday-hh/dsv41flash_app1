import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'asr_worker.dart';
import 'mic.dart';

/// 离线语音识别（sherpa-onnx + Paraformer-zh INT8，非流式整段识别）。
///
/// 设计要点：
/// - 模型只在首次使用时从 assets 复制到应用目录，之后按大小校验跳过；
/// - 推理在独立 isolate 中执行，主线程只做录音与 UI；
/// - 支持预热（不打开麦克风）与后台短暂保留，避免每次进面板都等待模型加载。
class AsrEngine {
  static bool get supported => true;

  /// 切到后台后模型保留时长（可在设置中调整 5/10/15/30 秒）
  static Duration backgroundRetention = const Duration(seconds: 15);

  /// 关闭后切后台立即释放模型
  static bool keepInBackground = true;

  static Isolate? _isolate;
  static SendPort? _commands;
  static ReceivePort? _responses;
  static Future<void>? _preparing;
  static Timer? _releaseTimer;
  static int _nextId = 0;
  static final Map<int, Completer<String>> _pending = <int, Completer<String>>{};
  static bool _background = false;
  static bool _enabled = false;
  static bool _disposed = false;

  static final BytesBuilder _pcm = BytesBuilder(copy: false);
  static StreamSubscription<Uint8List>? _sub;
  static bool _capturing = false;
  static double _level = 0;

  /// 最近一次采集的实时音量（0~1），用于波形动画
  static double get level => _level;

  static bool get isPreparing => _preparing != null && _commands == null;

  static bool get isReady => _commands != null;

  // ---------------------------------------------------------------- 模型 / isolate

  static const Map<String, String> _modelFiles = <String, String>{
    'model.int8.onnx': 'asr_model.int8.onnx',
    'tokens.txt': 'asr_tokens.txt',
  };

  /// 模型代号：只有替换了 assets/asr 下的文件才需要改。
  /// 用它代替“每次启动把 227MB 读进内存再比对”，启动阶段零大文件 IO。
  static const String _modelRev = 'paraformer-zh-int8-r1';

  /// 粗校验下限，防止拷贝被磁盘写满截断后仍然复用
  static const int _minModelBytes = 200 * 1024 * 1024;
  static const int _minTokensBytes = 50 * 1024;

  static Future<String> _ensureModel() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}/asr');
    if (!await dir.exists()) await dir.create(recursive: true);

    final File stamp = File('${dir.path}/.model_rev');
    final File model = File('${dir.path}/asr_model.int8.onnx');
    final File tokens = File('${dir.path}/asr_tokens.txt');

    bool sameRev = false;
    if (await stamp.exists()) {
      try {
        sameRev = (await stamp.readAsString()).trim() == _modelRev;
      } catch (_) {}
    }
    if (sameRev &&
        await model.exists() &&
        await model.length() > _minModelBytes &&
        await tokens.exists() &&
        await tokens.length() > _minTokensBytes) {
      return dir.path;
    }

    for (final MapEntry<String, String> e in _modelFiles.entries) {
      final File out = File('${dir.path}/${e.value}');
      final ByteData data = await rootBundle.load('assets/asr/${e.key}');
      if (await out.exists() && await out.length() == data.lengthInBytes) continue;
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    await stamp.writeAsString(_modelRev, flush: true);
    return dir.path;
  }

  /// 预热模型（不打开麦克风）。重复调用无副作用。
  static Future<void> warmUp() {
    if (_disposed) return Future<void>.value();
    // 先记下“用户希望常驻”，再判断前后台：否则首帧恰好处于后台时，
    // 之后回到前台也不会再自动预热。
    _enabled = true;
    if (_background) return Future<void>.value();
    final Future<void>? running = _preparing;
    if (running != null) return running;
    final Future<void> task = _prepare().catchError((Object _) {
      _preparing = null;
    });
    _preparing = task;
    return task;
  }

  static Future<void> _prepare() async {
    if (_commands != null) return;
    if (_disposed) throw StateError('语音已关闭');
    if (_background) throw StateError('语音已暂停');
    final String dir = await _ensureModel();
    if (_disposed) throw StateError('语音已关闭');
    if (_background) throw StateError('语音已暂停');
    final ReceivePort responses = ReceivePort();
    final Completer<SendPort> ready = Completer<SendPort>();
    responses.listen((Object? message) {
      final List<dynamic> data = message as List<dynamic>;
      final String tag = data[0] as String;
      if (tag == 'ready') {
        if (!ready.isCompleted) ready.complete(data[1] as SendPort);
        return;
      }
      if (tag == 'initError') {
        if (!ready.isCompleted) ready.completeError(StateError('${data[1]}'));
        return;
      }
      final Completer<String>? c = _pending.remove(data[1] as int);
      if (c == null) return;
      if (tag == 'ok') {
        c.complete('${data[2]}');
      } else {
        c.completeError(StateError('${data[2]}'));
      }
    });
    final Isolate isolate = await Isolate.spawn(
      asrWorkerMain,
      <Object?>[responses.sendPort, dir],
      debugName: 'whale-asr',
    );
    try {
      final SendPort commands = await ready.future.timeout(const Duration(seconds: 90));
      _isolate = isolate;
      _responses = responses;
      _commands = commands;
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      responses.close();
      rethrow;
    }
  }

  /// 释放模型与 isolate
  static Future<void> release() async {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    await cancelCapture();
    final Isolate? isolate = _isolate;
    _isolate = null;
    try {
      _commands?.send(<Object?>['close', 0]);
    } catch (_) {}
    _responses?.close();
    _responses = null;
    _commands = null;
    _preparing = null;
    try {
      isolate?.kill(priority: Isolate.immediate);
    } catch (_) {}
    for (final Completer<String> c in _pending.values) {
      if (!c.isCompleted) c.complete('');
    }
    _pending.clear();
  }

  // ---------------------------------------------------------------- 录音

  /// 开始采集，返回是否成功（会申请麦克风权限）
  ///
  /// 与录音并行推进模型准备：录音本身从不等待模型，这样即使冷启动后
  /// 立刻按住说话，松手时模型通常已经就绪。
  static Future<bool> startCapture() async {
    unawaited(warmUp());
    await cancelCapture();
    _pcm.clear();
    final bool ok = await Mic.start();
    if (!ok) return false;
    _capturing = true;
    _sub = Mic.stream.listen((Uint8List bytes) {
      if (!_capturing || bytes.isEmpty) return;
      _level = pcmLevel(bytes);
      _pcm.add(bytes);
    });
    return true;
  }

  /// 停止采集但不识别（取消）
  static Future<void> cancelCapture() async {
    _capturing = false;
    final StreamSubscription<Uint8List>? sub = _sub;
    _sub = null;
    await sub?.cancel();
    await Mic.stop();
    _pcm.clear();
    _level = 0;
  }

  /// 停止采集并把整段音频交给后台 isolate 识别
  static Future<String> stopAndRecognize() async {
    _capturing = false;
    final StreamSubscription<Uint8List>? sub = _sub;
    _sub = null;
    await sub?.cancel();
    await Mic.stop();
    final Uint8List bytes = _pcm.takeBytes();
    _level = 0;

    // 少于 0.2 秒基本是误触
    if (bytes.lengthInBytes < 6400) return '';
    await warmUp();
    final SendPort? port = _commands;
    if (port == null) throw StateError('语音模型未就绪');
    final int id = _nextId++;
    final Completer<String> completer = Completer<String>();
    _pending[id] = completer;
    port.send(<Object?>['recognize', id, pcm16ToFloat32(bytes)]);
    try {
      return await completer.future.timeout(const Duration(seconds: 40));
    } finally {
      _pending.remove(id);
    }
  }

  // ---------------------------------------------------------------- 生命周期

  static void onAppResumed() {
    _background = false;
    _releaseTimer?.cancel();
    _releaseTimer = null;
    if (_enabled && !_disposed) unawaited(warmUp());
  }

  static void onAppPaused() {
    _background = true;
    unawaited(cancelCapture());
    _releaseTimer?.cancel();
    _releaseTimer = null;
    if (!keepInBackground) {
      unawaited(release());
      return;
    }
    _releaseTimer = Timer(backgroundRetention, () {
      if (_background) unawaited(release());
    });
  }

  static void onMemoryPressure() {
    if (!_capturing) unawaited(release());
  }

  static Future<void> dispose() async {
    _disposed = true;
    await release();
  }
}
