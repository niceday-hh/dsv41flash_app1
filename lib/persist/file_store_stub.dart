import 'package:shared_preferences/shared_preferences.dart';

const String _key = 'whale_ledger_v2';

Future<String?> readLedger() async {
  try {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getString(_key);
  } catch (_) {
    return null;
  }
}

Future<void> writeLedger(String data) async {
  try {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString(_key, data);
  } catch (_) {}
}
