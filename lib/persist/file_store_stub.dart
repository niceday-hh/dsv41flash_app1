import 'package:shared_preferences/shared_preferences.dart';

const String _key = 'whale_ledger_v2';
const String _calendarKey = 'whale_calendar_v1';

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

Future<String?> readCalendar() async {
  try {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getString(_calendarKey);
  } catch (_) {
    return null;
  }
}

Future<void> writeCalendar(String data) async {
  try {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString(_calendarKey, data);
  } catch (_) {}
}
