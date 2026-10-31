import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 语音识别的后台 isolate 入口。
///
/// 模型加载与推理都发生在这里，主 isolate 只负责录音与 UI，
/// 因此长音频解码时界面不会掉帧。
void asrWorkerMain(List<Object?> args) {
  final SendPort main = args[0] as SendPort;
  final String dir = args[1] as String;
  final ReceivePort inbox = ReceivePort();

  sherpa.OfflineRecognizer? recognizer;
  try {
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        feat: const sherpa.FeatureConfig(sampleRate: 16000, featureDim: 80),
        model: sherpa.OfflineModelConfig(
          paraformer: sherpa.OfflineParaformerModelConfig(model: '$dir/asr_model.int8.onnx'),
          tokens: '$dir/asr_tokens.txt',
          numThreads: 2,
          modelType: 'paraformer',
          debug: false,
        ),
        decodingMethod: 'greedy_search',
      ),
    );
    main.send(<Object?>['ready', inbox.sendPort]);
  } catch (e) {
    main.send(<Object?>['initError', e.toString()]);
    inbox.close();
    return;
  }

  inbox.listen((Object? message) {
    final List<dynamic> data = message as List<dynamic>;
    final String cmd = data[0] as String;
    final int id = data[1] as int;
    if (cmd == 'recognize') {
      final Float32List samples = data[2] as Float32List;
      sherpa.OfflineStream? stream;
      try {
        stream = recognizer!.createStream();
        stream.acceptWaveform(samples: samples, sampleRate: 16000);
        recognizer.decode(stream);
        final String text = recognizer.getResult(stream).text;
        main.send(<Object?>['ok', id, text]);
      } catch (e) {
        main.send(<Object?>['error', id, e.toString()]);
      } finally { stream?.free(); }
    } else if (cmd == 'close') {
      try {
        recognizer!.free();
      } catch (_) {}
      inbox.close();
    }
  });
}

