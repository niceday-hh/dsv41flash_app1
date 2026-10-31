import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import '../lib/voice/asr_worker.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

// The same Dart FFI/configuration used by the app, with the pinned real model.
Future<void> main() async {
  sherpa.initBindings();
  final recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(paraformer: const sherpa.OfflineParaformerModelConfig(model: '.voice-model-cache/model.int8.onnx'),
      tokens: '.voice-model-cache/tokens.txt', modelType: 'paraformer', numThreads: 2, debug: false)));
  final stream = recognizer.createStream();
  try {
    final wave = sherpa.readWave('.voice-model-cache/test_wavs/0.wav');
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;
    print('Real Paraformer Mandarin smoke transcription: $text');
    if (!text.contains('研究') || !text.contains('感兴趣')) throw StateError('Unexpected Mandarin transcription');
  } finally { stream.free(); recognizer.free(); }
  // Verify the actual app worker acknowledges explicit native free().
  for (final pair in {'asr_model.int8.onnx':'model.int8.onnx', 'asr_tokens.txt':'tokens.txt'}.entries) {
    final link = Link('.voice-model-cache/${pair.key}');
    if (!link.existsSync()) link.createSync(pair.value);
  }
  final ready = Completer<SendPort>(), closed = Completer<void>();
  final responses = ReceivePort();
  responses.listen((dynamic data) {
    if (data[0] == 'ready') ready.complete(data[1] as SendPort);
    if (data[0] == 'closed') closed.complete();
    if (data[0] == 'initError') ready.completeError(StateError('${data[1]}'));
  });
  final worker = await Isolate.spawn(asrWorkerMain, <Object?>[responses.sendPort,'.voice-model-cache']);
  try {
    final commands = await ready.future.timeout(const Duration(seconds:45));
    commands.send(<Object?>['close',0]);
    await closed.future.timeout(const Duration(seconds:10));
    print('Real app worker explicit native release acknowledged');
  } finally { responses.close(); worker.kill(priority:Isolate.immediate); }
  final apk = File('build/app/outputs/flutter-apk/app-release.apk');
  if (apk.existsSync()) print('APK bytes: ${apk.lengthSync()}');
}

