import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/app_shell.dart';
import 'package:whale_ledger/store.dart';
import 'package:whale_ledger/theme.dart';
import 'package:whale_ledger/ui/common.dart';
import 'package:whale_ledger/ui/entry_launcher.dart';
import 'package:whale_ledger/voice/asr_engine_mobile.dart';
import 'voice_completion_test.dart' show FakeWorker, speech;

void main() {
  testWidgets('home voice keeps date through fill and saves only on confirmation', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(); final p = Palette.of(false, 0);
    final pcm = StreamController<Uint8List>.broadcast(sync: true);
    await AsrEngine.configureForTest(worker: () => FakeWorker()..text = '10月1号买纸巾16元',
      start: () async => true, stop: () async {}, stream: () => pcm.stream);
    await AsrEngine.warmUp();
    await tester.pumpWidget(AppScope(store: store, palette: p,
      child: MaterialApp(theme: buildTheme(p), home: const AppShell())));
    await tester.pumpAndSettle();
    // This invokes the real home callback, not a parallel test-only save route.
    tester.widget<EntryLauncher>(find.byType(EntryLauncher)).onVoice();
    await tester.pump(); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();
    final g = await tester.startGesture(tester.getCenter(find.text('按住 说话')));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 20)); pcm.add(speech()); await tester.pump(const Duration(milliseconds: 500));
    await g.up(); await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds:20)); }); await tester.pump(); await tester.pump(const Duration(milliseconds: 200)); await tester.pump();
    for (var i=0; i<20 && find.text('重说').evaluate().isEmpty; i++) { await tester.pump(const Duration(milliseconds:50)); }
    debugPrint('Voice state: ${tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data).whereType<String>().join(' | ')}');
    expect(find.text('10月1日'), findsOneWidget); expect(store.bills, isEmpty);
    await tester.tap(find.text('填入账单')); await tester.pumpAndSettle();
    expect(find.text('记一笔'), findsOneWidget); expect(store.bills, isEmpty);
    await tester.tap(find.textContaining('保存 ·')); await tester.pumpAndSettle();
    expect(store.bills.length, 1);
    final b = store.bills.single;
    expect([b.date.month,b.date.day], [10,1]); expect(b.amount,16); expect(b.catId,'daily'); expect(b.note,'纸巾');
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();
    await tester.runAsync(store.flushPersistence);
    await AsrEngine.dispose(); await pcm.close(); store.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('plus tap, swipe selection and cancelled swipe retain existing actions', (tester) async {
    final store = AppStore(); final p = Palette.of(false,0); var manual=0,voice=0;
    await tester.pumpWidget(AppScope(store:store,palette:p,child:MaterialApp(home:Scaffold(
      body:Align(alignment:Alignment.bottomCenter,child:SizedBox(width:80,height:80,
        child:EntryLauncher(onManual:()=>manual++,onVoice:()=>voice++)))))));
    final add = find.byIcon(Icons.add_rounded);
    await tester.tap(add); await tester.pumpAndSettle(); expect(manual,1);
    final origin = tester.getCenter(add);
    var g = await tester.startGesture(origin);
    await g.moveTo(origin+const Offset(86,-118)); await tester.pump(const Duration(milliseconds:200));
    expect(voice,0); await g.up(); await tester.pumpAndSettle(); expect(voice,1);
    g = await tester.startGesture(origin); await g.moveTo(origin+const Offset(0,-50));
    await tester.pump(const Duration(milliseconds:200)); await g.cancel(); await tester.pumpAndSettle();
    expect(manual,1); expect(voice,1);
    await tester.pumpWidget(const SizedBox.shrink()); store.dispose();
  });
}
