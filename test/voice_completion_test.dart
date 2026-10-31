import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/models.dart';
import 'package:whale_ledger/voice/voice_parser.dart';
import 'package:whale_ledger/voice/asr_engine_mobile.dart';
import 'package:whale_ledger/voice/model_worker.dart';

class FakeWorker implements ModelWorker {
  Completer<void>? ready, closeGate;
  Completer<String>? decoding;
  bool closed = false;
  int preparations = 0, decodes = 0;
  String text = '午饭28元，备注牛肉面';
  @override Future<void> prepare() async { preparations++; await ready?.future; }
  @override Future<String> recognize(Float32List samples) async { decodes++; return decoding == null ? text : decoding!.future; }
  @override Future<void> close() async { closed = true; await closeGate?.future; }
}
Uint8List speech() {
  final bytes = Uint8List(16000);
  for (var i = 0; i < bytes.length; i += 2) { bytes[i] = 0x80; bytes[i + 1] = 0x10; }
  return bytes;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> tick() => Future.delayed(Duration.zero);
  final now = DateTime(2026, 10, 31);
  test('history uses full per-category counts, recency, longest merchant and both modes', () {
    final bills = <Bill>[];
    void add(String note, String cat, {bool expense = true, int days = 0}) {
      bills.add(Bill(id: '${bills.length}', catId: cat, amount: 1, expense: expense,
        date: now.subtract(Duration(days: days)), note: note));
    }
    add('盒马', 'food'); add('盒马', 'daily');
    var history = voiceHistory(bills);
    expect(history.length, 2);
    expect(parseVoice('盒马58元', history: history, now: now).catId, 'other');
    for (var i = 0; i < 12; i++) { add('盒马', 'food', days: i); }
    add('盒马', 'parttime', expense: false);
    for (var i = 0; i < 220; i++) { add('其他商家$i', 'shop'); }
    history = voiceHistory(bills);
    expect(parseVoice('盒马买东西58元', history: history, now: now).catId, 'food');
    expect(parseVoice('盒马收入58元', history: history, now: now).catId, 'parttime');
    expect(parseVoice('盒马买纸巾58元', history: history, now: now).catId, 'daily');
    expect(parseVoice('盒马58元分类购物', history: history, now: now).catId, 'shop');
    expect(parseVoice('盒马鲜生58元', history: [...history, NoteHint('盒马鲜生（万象城店）', 'fruit', 2)], now: now).catId, 'fruit');
    expect(parseVoice('小象买菜38元', history: [NoteHint('小象买菜', 'food', 4)], now: now).catId, 'food');
  });
  test('explicit remarks never supply transaction amount, date or income', () {
    final p = parseVoice('昨天午饭28元，备注买了2杯咖啡', now: now);
    expect(p.amount, 28); expect(p.date.day, 30); expect(p.note, '买了2杯咖啡');
    expect(parseVoice('买纸巾16元，备注工资', now: now).expense, isTrue);
    expect(parseVoice('备注牛肉面，花了28元').amount, 28);
    expect(parseVoice('备注牛肉面，花了28元').note, '牛肉面');
    expect(parseVoice('奶茶18元地铁6元').valid, isFalse);
    expect(parseVoice('分类礼金，收入100元').catId, 'gift');
  });
  test('Whale vocabulary, financial numerals and compact remarks survive', () {
    for (final c in {'剧本杀80元':'fun','寄件12元':'express','清洁30元':'daily', '幼儿园200元':'child'}.entries) {
      expect(parseVoice(c.key).catId, c.value, reason: c.key);
    }
    expect(parseVoice('买咖啡花了28块').note, '咖啡');
    expect(parseVoice('咖啡贰拾捌元伍角').amount, 28.5);
    expect(parseVoice('奶茶 三 圆 五 角').amount, 3.5);
  });
  test('large history parsing is isolate-safe and respects type/note overrides', () async {
    final parsed = await parseVoiceAsync('盒马收入58元', history: [NoteHint('盒马', 'food', 5),
      for (var i=0;i<250;i++) NoteHint('商家$i','shop',1)], expenseOverride: true, noteOverride: '');
    expect(parsed.catId, 'food'); expect(parsed.expense, isTrue); expect(parsed.note, '');
  });

  late StreamController<Uint8List> pcm;
  late List<FakeWorker> workers;
  var stops = 0;
  Future<void> configure({Completer<void>? gate, Completer<bool>? permission}) async {
    pcm = StreamController<Uint8List>.broadcast(sync: true); workers = []; stops = 0;
    await AsrEngine.configureForTest(worker: () { final w = FakeWorker()..ready = gate; workers.add(w); return w; },
      start: () async => permission == null ? true : permission.future,
      stop: () async { stops++; }, stream: () => pcm.stream);
  }
  tearDown(() async { await AsrEngine.dispose(); if (!pcm.isClosed) await pcm.close(); });
  setUp(() { pcm = StreamController<Uint8List>.broadcast(); });
  test('cold model and capture run in parallel with one initialization', () async {
    final gate = Completer<void>(); await configure(gate: gate);
    final warming = AsrEngine.warmUp();
    expect(await AsrEngine.startCapture(), isTrue); pcm.add(speech());
    final result = AsrEngine.stopAndRecognize(); await tick();
    expect(stops, greaterThan(0)); expect(workers.single.decodes, 0);
    gate.complete(); await warming;
    expect(await result, contains('28')); expect(workers.single.preparations, 1);
    await AsrEngine.cancelCapture(); await AsrEngine.warmUp(); expect(workers.length, 1);
  });
  test('cancel during permission does not resume capture after dismissal', () async {
    final permission = Completer<bool>(); await configure(permission: permission);
    final starting = AsrEngine.startCapture(); await tick();
    await AsrEngine.cancelCapture(); permission.complete(true);
    expect(await starting, isFalse);
  });
  test('cancelled pending decode cannot return a stale result', () async {
    await configure(); await AsrEngine.warmUp();
    await AsrEngine.startCapture(); pcm.add(speech());
    final worker = workers.single..decoding = Completer<String>();
    final result = AsrEngine.stopAndRecognize(); await tick();
    await AsrEngine.cancelCapture(); worker.decoding!.complete('旧账单100元');
    expect(await result, isEmpty); expect(worker.closed, isTrue);
  });
  test('new model waits for native release acknowledgement', () async {
    await configure(); await AsrEngine.warmUp();
    final old = workers.single..closeGate = Completer<void>();
    final retiring = AsrEngine.release();
    final warming = AsrEngine.warmUp(); await tick();
    expect(old.closed,isTrue); expect(workers.length,1);
    old.closeGate!.complete(); await retiring; await warming;
    expect(workers.length,2);
  });
  test('background before preparation starts can retry on quick resume', () async {
    await configure();
    final warming = AsrEngine.warmUp(); AsrEngine.onAppPaused();
    await warming; AsrEngine.onAppResumed(); await AsrEngine.warmUp();
    expect(AsrEngine.isReady,isTrue); expect(workers.length,1);
  });
  test('silence and very short capture never reach recognition', () async {
    await configure(); await AsrEngine.startCapture(); pcm.add(Uint8List(16000));
    await expectLater(AsrEngine.stopAndRecognize(), throwsStateError);
    await AsrEngine.startCapture(); pcm.add(Uint8List(100));
    await expectLater(AsrEngine.stopAndRecognize(), throwsStateError);
    expect(workers.single.decodes, 0);
  });
  testWidgets('background grace is bounded, settings react immediately, pressure releases', (tester) async {
    await tester.runAsync(() async { await configure(); }); var clock = now;
    await AsrEngine.configureForTest(worker: () { final w = FakeWorker(); workers.add(w); return w; },
      clock: () => clock, start: () async => true, stop: () async {}, stream: () => pcm.stream);
    await AsrEngine.warmUp(); final old = workers.single;
    AsrEngine.onAppPaused(); clock = clock.add(const Duration(seconds: 10));
    AsrEngine.onAppPaused(); AsrEngine.onAppResumed(); await AsrEngine.warmUp();
    expect(workers.length, 1); expect(old.closed, isFalse);
    AsrEngine.onAppPaused(); clock = clock.add(const Duration(seconds: 20));
    AsrEngine.onAppResumed(); await AsrEngine.warmUp(); expect(old.closed, isTrue); expect(workers.length, 2);
    AsrEngine.onAppPaused(); AsrEngine.keepInBackground = false; await tester.pump();
    expect(workers.last.closed, isTrue);
    AsrEngine.onAppResumed(); await AsrEngine.warmUp(); AsrEngine.onMemoryPressure();
    expect(workers.last.closed, isTrue);
    await AsrEngine.dispose(); await pcm.close();
  });
}
