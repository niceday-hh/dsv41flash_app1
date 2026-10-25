/// 语音识别对外统一入口（移动端实现见 asr_engine_mobile.dart，Web 走 stub）。
export 'asr_engine_stub.dart' if (dart.library.io) 'asr_engine_mobile.dart';
