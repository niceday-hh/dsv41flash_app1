import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'mic.dart';

/// 离线语音识别（sherpa-onnx + 中文流式 Zipformer 14M）
/// 模型随包内置，首次使用时复制到应用目录，无需联网。
class AsrEngine {
  static bool get supported => true;

  static const List<String> _files = <String>[
    'encoder-epoch-99-avg-1.int8.onnx',
    'decoder-epoch-99-avg-1.onnx',
    'joiner-epoch-99-avg-1.int8.onnx',
    'tokens.txt',
  ];

  final sherpa.OnlineRecognizer _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription<Uint8List>? _sub;

  AsrEngine._(this._recognizer);

  /// 全局缓存：模型只加载一次，后续打开面板秒开
  static Future<AsrEngine?>? _cached;

  static Future<AsrEngine?> create() {
    return _cached ??= _build();
  }

  static Future<AsrEngine?> _build() async {
    try {
      final String dir = await _ensureModel();
      sherpa.initBindings();
      final sherpa.OnlineRecognizer recognizer = sherpa.OnlineRecognizer(
        sherpa.OnlineRecognizerConfig(
          feat: const sherpa.FeatureConfig(sampleRate: 16000, featureDim: 80),
          model: sherpa.OnlineModelConfig(
            transducer: sherpa.OnlineTransducerModelConfig(
              encoder: '$dir/encoder-epoch-99-avg-1.int8.onnx',
              decoder: '$dir/decoder-epoch-99-avg-1.onnx',
              joiner: '$dir/joiner-epoch-99-avg-1.int8.onnx',
            ),
            tokens: '$dir/tokens.txt',
            numThreads: 2,
            modelType: 'zipformer',
            debug: false,
          ),
          decodingMethod: 'greedy_search',
          enableEndpoint: true,
          rule1MinTrailingSilence: 2.4,
          rule2MinTrailingSilence: 1.2,
        ),
      );
      return AsrEngine._(recognizer);
    } catch (_) {
      _cached = null;
      return null;
    }
  }

  /// 把 assets/asr 下的模型复制到可读目录，返回目录路径
  static Future<String> _ensureModel() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}/asr');
    if (!await dir.exists()) await dir.create(recursive: true);
    for (final String name in _files) {
      final File file = File('${dir.path}/$name');
      final ByteData data = await rootBundle.load('assets/asr/$name');
      if (await file.exists() && await file.length() == data.lengthInBytes) continue;
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return dir.path;
  }

  Future<void> start({
    required void Function(String partial) onPartial,
    required void Function(double level) onLevel,
  }) async {
    await stop();
    final bool ok = await Mic.start();
    if (!ok) throw Exception('麦克风不可用');
    final sherpa.OnlineStream stream = _recognizer.createStream();
    _stream = stream;
    _sub = Mic.stream.listen((Uint8List bytes) {
      if (bytes.isEmpty) return;
      onLevel(pcmLevel(bytes));
      stream.acceptWaveform(samples: pcm16ToFloat32(bytes), sampleRate: 16000);
      while (_recognizer.isReady(stream)) {
        _recognizer.decode(stream);
      }
      final String text = _recognizer.getResult(stream).text;
      if (text.isNotEmpty) onPartial(text);
    });
  }

  Future<String> stop() async {
    await _sub?.cancel();
    _sub = null;
    await Mic.stop();
    final sherpa.OnlineStream? stream = _stream;
    _stream = null;
    if (stream == null) return '';
    String text = '';
    try {
      stream.acceptWaveform(samples: Float32List(1600), sampleRate: 16000);
      while (_recognizer.isReady(stream)) {
        _recognizer.decode(stream);
      }
      text = _recognizer.getResult(stream).text;
    } catch (_) {}
    stream.free();
    return text;
  }

  /// 只停止当前录音与流，保留已加载的模型供下次复用
  Future<void> dispose() async {
    await stop();
  }
}
