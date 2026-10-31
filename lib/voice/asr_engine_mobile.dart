import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'mic.dart';
import 'model_worker.dart';

/// Shared foreground model; recording is independent from preparation.
class AsrEngine {
  static bool get supported => true;
  static Duration _retention = const Duration(seconds: 15);
  static bool _keep = true;
  static Duration get backgroundRetention => _retention;
  static set backgroundRetention(Duration value) {
    _retention = Duration(milliseconds: value.inMilliseconds.clamp(0, 30000));
    if (_background) _scheduleRelease();
  }
  static bool get keepInBackground => _keep;
  static set keepInBackground(bool value) { _keep = value; if (_background) _scheduleRelease(); }
  static ModelWorker Function() _factory = LocalModelWorker.new;
  static Future<bool> Function() _startMic = Mic.start;
  static Future<void> Function() _stopMic = Mic.stop;
  static Stream<Uint8List> Function() _micStream = () => Mic.stream;
  static DateTime Function() _clock = DateTime.now;
  static ModelWorker? _worker;
  static Future<void>? _preparing;
  static bool _ready = false, _background = false, _enabled = false, _disposed = false;
  static bool _capturing = false, _decoding = false, _pressure = false;
  static int _generation = 0, _captureGeneration = 0;
  static Timer? _releaseTimer;
  static DateTime? _backgroundSince;
  static Future<void> _micTransition = Future.value();
  static final BytesBuilder _pcm = BytesBuilder(copy: false);
  static StreamSubscription<Uint8List>? _sub;
  static double _level = 0;
  static double get level => _level;
  static bool get isPreparing => _preparing != null && !_ready;
  static bool get isReady => _ready;

  static Future<void> warmUp() async {
    if (_disposed) return;
    _enabled = true;
    if (_background) return;
    try { await _prepare(); } catch (_) {} // Manual bookkeeping always works.
  }
  static Future<void> _prepare() {
    if (_disposed || _background) return Future.error(StateError('语音已暂停'));
    if (_ready) return Future.value();
    return _preparing ??= _prepareCurrent();
  }
  static Future<void> _prepareCurrent() async {
    final generation = _generation;
    final worker = _worker ??= _factory();
    try {
      await worker.prepare().timeout(const Duration(seconds: 45));
      if (_disposed || generation != _generation || !identical(worker, _worker)) throw StateError('语音准备已取消');
      _ready = true;
    } catch (_) {
      if (identical(worker, _worker)) { _worker = null; _ready = false; _preparing = null; }
      worker.close(); rethrow;
    }
  }
  static Future<void> release() {
    _generation++; _preparing = null; _ready = false; _pressure = false;
    _releaseTimer?.cancel(); _releaseTimer = null;
    final worker = _worker; _worker = null; worker?.close();
    return cancelCapture(refreshModel: false);
  }

  static Future<bool> startCapture() async {
    if (_background || _disposed) return false;
    unawaited(warmUp());
    await cancelCapture();
    final generation = _captureGeneration;
    final started = Completer<void>();
    final previous = _micTransition;
    _micTransition = started.future;
    try {
      await previous;
      if (_background || _disposed || generation != _captureGeneration) return false;
      // Subscribe before AudioRecord starts to retain the first syllable.
      _capturing = true;
      _sub = _micStream().listen((bytes) {
        if (!_capturing || generation != _captureGeneration || bytes.isEmpty) return;
        _level = pcmLevel(bytes);
        _pcm.add(bytes);
        // Hard cap of 30 seconds even if a page timer is delayed.
        if (_pcm.length >= 16000 * 2 * 30) unawaited(_stopMic());
      });
      final ok = await _startMic();
      if (!ok || _background || _disposed || generation != _captureGeneration) {
        await _stopMic(); await _sub?.cancel(); _sub = null;
        _capturing = false; _pcm.clear(); return false;
      }
      return true;
    } finally { started.complete(); }
  }
  static Future<void> cancelCapture({bool refreshModel = true}) {
    final needsStop = _capturing || _sub != null;
    if (_decoding && _worker != null) {
      _generation++; _worker?.close(); _worker = null; _preparing = null; _ready = false;
      if (refreshModel && !_pressure && !_background && !_disposed && _enabled) unawaited(warmUp());
    }
    _decoding = false;
    if (_pressure) {
      _generation++; _worker?.close(); _worker = null; _preparing = null; _ready = false; _pressure = false;
    }
    _captureGeneration++; _capturing = false; _level = 0;
    final sub = _sub; _sub = null; _pcm.clear();
    // Stop immediately, including any outstanding native permission request.
    final stop = needsStop ? _stopMic() : Future<void>.value();
    return Future.wait<void>([if (sub != null) sub.cancel(), stop]).then((_) {});
  }
  static Future<String> stopAndRecognize() async {
    final generation = _captureGeneration;
    await _micTransition;
    _capturing = false; _level = 0;
    await _stopMic();
    await _sub?.cancel(); _sub = null;
    final bytes = _pcm.takeBytes();
    if (_disposed || _background || generation != _captureGeneration) return '';
    if (bytes.length < 11200) throw StateError('录音太短，请完整说一句');
    final samples = pcm16ToFloat32(bytes);
    var power = 0.0;
    for (final sample in samples) { power += sample * sample; }
    if (power / samples.length < .000001) throw StateError('声音太轻或未检测到语音，请重试');
    _decoding = true;
    try {
      await _prepare();
      if (_background || _disposed || generation != _captureGeneration) return '';
      final text = await _worker!.recognize(samples);
      return _background || _disposed || generation != _captureGeneration ? '' : text;
    } finally {
      if (generation == _captureGeneration) {
        _decoding = false;
        if (_pressure) unawaited(release());
      }
    }
  }
  static void _scheduleRelease() {
    _releaseTimer?.cancel(); _releaseTimer = null;
    if (!_background) return;
    final elapsed = _clock().difference(_backgroundSince ?? _clock());
    final remaining = (_keep ? _retention : Duration.zero) - elapsed;
    if (remaining <= Duration.zero) { unawaited(release()); }
    else { _releaseTimer = Timer(remaining, () { if (_background) unawaited(release()); }); }
  }
  static void onAppResumed() {
    final since = _backgroundSince;
    if (_background && since != null && (!_keep || _clock().difference(since) >= _retention)) unawaited(release());
    _background = false; _backgroundSince = null;
    _releaseTimer?.cancel(); _releaseTimer = null;
    if (_enabled && !_disposed) unawaited(warmUp());
  }
  static void onAppPaused() {
    if (_background) return; // hidden -> paused does not reset the deadline.
    _background = true; _backgroundSince = _clock();
    unawaited(cancelCapture());
    if (_decoding || _pressure) { unawaited(release()); }
    else { _scheduleRelease(); }
  }
  static void onMemoryPressure() {
    if (!_capturing || _background) { unawaited(release()); }
    else { _pressure = true; }
  }
  static Future<void> dispose() async { _disposed = true; await release(); }

  @visibleForTesting
  static Future<void> configureForTest({ModelWorker Function()? worker,
      Future<bool> Function()? start, Future<void> Function()? stop,
      Stream<Uint8List> Function()? stream, DateTime Function()? clock}) async {
    await release();
    _factory = worker ?? LocalModelWorker.new;
    _startMic = start ?? Mic.start; _stopMic = stop ?? Mic.stop;
    _micStream = stream ?? () => Mic.stream; _clock = clock ?? DateTime.now;
    _background = false; _backgroundSince = null; _enabled = false; _disposed = false;
    _keep = true; _retention = const Duration(seconds: 15); _micTransition = Future.value();
  }
}
