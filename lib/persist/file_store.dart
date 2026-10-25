/// 跨平台账本落盘入口：
/// - Android / iOS / 桌面 → 应用私有目录下的 JSON 文件（原子替换）
/// - Web → localStorage（shared_preferences）
import 'file_store_stub.dart' if (dart.library.io) 'file_store_io.dart' as impl;

Future<String?> readLedger() => impl.readLedger();

Future<void> writeLedger(String data) => impl.writeLedger(data);
