import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String ledgerFileName = 'ledger.json';

Future<File> _ledgerFile() async {
  final Directory dir = await getApplicationSupportDirectory();
  if (!await dir.exists()) await dir.create(recursive: true);
  return File('${dir.path}/$ledgerFileName');
}

Future<String?> readLedger() async {
  try {
    final File f = await _ledgerFile();
    if (!await f.exists()) return null;
    final String raw = await f.readAsString();
    return raw.isEmpty ? null : raw;
  } catch (_) {
    return null;
  }
}

Future<void> writeLedger(String data) async {
  try {
    final File f = await _ledgerFile();
    // 先写临时文件再 rename，避免写入中断留下半个 JSON
    final File tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  } catch (_) {
    // 写盘失败时保留内存中的账本，不打断使用
  }
}
