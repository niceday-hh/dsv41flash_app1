/// Web / 桌面占位实现：不具备离线语音能力。
class AsrEngine {
  static bool get supported => false;

  static Future<AsrEngine?> create() async => null;

  Future<void> start({
    required void Function(String partial) onPartial,
    required void Function(double level) onLevel,
  }) async {}

  Future<String> stop() async => '';

  Future<void> dispose() async {}
}
