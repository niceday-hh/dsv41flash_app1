import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// CSV 文件读写桥接：Android 走系统文件选择器（SAF），其余平台返回不支持。
class CsvFileService {
  static const MethodChannel _channel = MethodChannel('whale_ledger/csv');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 另存为 CSV，返回是否保存成功
  static Future<bool> save(String filename, String content) async {
    if (!supported) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'save',
        <String, dynamic>{'filename': filename, 'content': content},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 选择 CSV 文件并读取文本，取消或失败返回 null
  static Future<String?> pick() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('pick');
    } catch (_) {
      return null;
    }
  }
}
