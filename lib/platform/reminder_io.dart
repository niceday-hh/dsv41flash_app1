import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('whale_ledger/reminder');

const bool supported = true;

Future<bool> schedule(int hour, int minute) async {
  try {
    final bool? ok = await _channel.invokeMethod<bool>('schedule', <String, dynamic>{
      'hour': hour,
      'minute': minute,
    });
    return ok ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> cancel() async {
  try {
    await _channel.invokeMethod<void>('cancel');
  } catch (_) {
    // 忽略：原生端不可用时不影响开关状态
  }
}

Future<bool> test() async {
  try {
    final bool? ok = await _channel.invokeMethod<bool>('test');
    return ok ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> restore() async {
  try {
    await _channel.invokeMethod<void>('restore');
  } catch (_) {
    // 忽略
  }
}
