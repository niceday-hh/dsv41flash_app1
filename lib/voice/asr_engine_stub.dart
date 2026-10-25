/// Web / 桌面占位实现：不具备离线语音能力，接口与移动端保持一致。
class AsrEngine {
  static bool get supported => false;

  static Duration backgroundRetention = const Duration(seconds: 15);
  static bool keepInBackground = true;

  static double get level => 0;
  static bool get isPreparing => false;
  static bool get isReady => false;

  static Future<void> warmUp() async {}

  static Future<void> release() async {}

  static Future<bool> startCapture() async => false;

  static Future<void> cancelCapture() async {}

  static Future<String> stopAndRecognize() async => '';

  static void onAppResumed() {}

  static void onAppPaused() {}

  static void onMemoryPressure() {}

  static Future<void> dispose() async {}
}
