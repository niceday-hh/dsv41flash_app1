import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 原生麦克风采集（16kHz / 单声道 / PCM16），通过 EventChannel 持续推送字节块。
class Mic {
  static const MethodChannel _method = MethodChannel('whale_ledger/mic');
  static const EventChannel _events = EventChannel('whale_ledger/mic_stream');

  static Stream<Uint8List>? _stream;

  /// 开始录音，返回是否成功（会申请录音权限）
  static Future<bool> start() async {
    try {
      final bool? ok = await _method.invokeMethod<bool>('start');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _method.invokeMethod<void>('stop');
    } catch (_) {}
  }

  static Stream<Uint8List> get stream {
    _stream ??= _events.receiveBroadcastStream().map((dynamic e) {
      if (e is Uint8List) return e;
      if (e is List<int>) return Uint8List.fromList(e);
      return Uint8List(0);
    });
    return _stream!;
  }
}

/// PCM16 小端字节 → 归一化浮点采样
Float32List pcm16ToFloat32(Uint8List bytes) {
  final int count = bytes.lengthInBytes ~/ 2;
  final Float32List out = Float32List(count);
  final ByteData data = ByteData.sublistView(bytes);
  for (int i = 0; i < count; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// 估算音量（0~1），用于波形动画
double pcmLevel(Uint8List bytes) {
  if (bytes.isEmpty) return 0;
  int peak = 0;
  for (int i = 0; i + 1 < bytes.length; i += 2) {
    final int v = (bytes[i] | (bytes[i + 1] << 8)).toSigned(16).abs();
    if (v > peak) peak = v;
  }
  return (peak / 32768.0).clamp(0.0, 1.0);
}
