import 'reminder_stub.dart' if (dart.library.io) 'reminder_io.dart' as impl;

/// 每日记账提醒的系统调度入口。
///
/// Android 端走原生 AlarmManager + 通知渠道；Web 端为空实现。
class ReminderService {
  static bool get supported => impl.supported;

  /// 登记每天 [hour]:[minute] 的提醒，返回是否已获得通知权限
  static Future<bool> schedule(int hour, int minute) => impl.schedule(hour, minute);

  static Future<void> cancel() => impl.cancel();

  /// 立刻弹一条通知，用于让用户确认通知是否正常
  static Future<bool> test() => impl.test();

  /// 启动时补登记（防止系统清理或升级后闹钟丢失）
  static Future<void> restore() => impl.restore();
}
