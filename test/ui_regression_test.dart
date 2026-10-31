import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/app_shell.dart';
import 'package:whale_ledger/store.dart';
import 'package:whale_ledger/theme.dart';
import 'package:whale_ledger/ui/common.dart';
import 'package:whale_ledger/ui/add_sheet.dart';
import 'package:whale_ledger/voice/voice_sheet.dart';
import 'package:whale_ledger/voice/model_worker.dart';
import 'package:whale_ledger/voice/asr_engine_mobile.dart';

class UiWorker implements ModelWorker {
  @override Future<void> prepare() async {}
  @override Future<String> recognize(Float32List samples) async => '午饭28元，备注牛肉面';
  @override Future<void> close() async {}
}
void main() {
  setUpAll(() async {
    final loader = FontLoader('WenKai')..addFont(rootBundle.load('assets/fonts/LXGWWenKai-subset.ttf'));
    await loader.load();
  });
  for (final dark in [false, true]) {
    testWidgets('1.5.7 UI parity ${dark ? 'dark' : 'light'}', (tester) async {
      final originalError = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint('Visual fixture error: ${details.exceptionAsString()}');
        debugPrintStack(stackTrace: details.stack);
        originalError?.call(details);
      };
      addTearDown(() { FlutterError.onError = originalError; });
      tester.view.physicalSize = const Size(420, 900); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore(); final p = Palette.of(dark, 0);
      final pcm = StreamController<Uint8List>.broadcast(sync: true);
      await AsrEngine.configureForTest(worker: UiWorker.new, start: () async => true,
        stop: () async {}, stream: () => pcm.stream);
      await AsrEngine.warmUp();
      debugPrint('UI baseline: model fixture ready');
      await tester.pumpWidget(AppScope(store: store, palette: p, child: MaterialApp(
        theme: buildTheme(p), home: const AppShell())));
      await tester.pumpAndSettle();
      debugPrint('UI baseline: home settled');
      final root = find.byType(MaterialApp);
      final label = dark ? 'dark' : 'light';
      await expectLater(root, matchesGoldenFile('goldens/home_$label.png'));
      debugPrint('UI baseline: home captured');
      final context = tester.element(find.byType(AppShell));
      unawaited(showAddBillSheet(context)); await tester.pumpAndSettle();
      await expectLater(root, matchesGoldenFile('goldens/manual_$label.png'));
      debugPrint('UI baseline: manual captured');
      Navigator.of(context).pop(); await tester.pumpAndSettle();
      unawaited(showVoiceSheet(context)); await tester.pump(); await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await expectLater(root, matchesGoldenFile('goldens/voice_$label.png'));
      expect(find.text('按住 说话'), findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(find.text('按住 说话')));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 20));
      final bytes = Uint8List(16000); for (var i=0;i<bytes.length;i+=2) { bytes[i]=128; bytes[i+1]=16; }
      pcm.add(bytes); await tester.pump(const Duration(milliseconds: 480));
      await gesture.up(); await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds:20)); }); await tester.pump(); await tester.pump(const Duration(milliseconds: 200)); await tester.pump();
      for (var i=0; i<20 && find.text('重说').evaluate().isEmpty; i++) { await tester.pump(const Duration(milliseconds:50)); }
      debugPrint('Voice state: ${tester.widgetList<Text>(find.byType(Text)).map((t)=>t.data).whereType<String>().join(' | ')}');
      debugPrint('UI baseline: recognition returned');
      expect(find.text('重说'), findsOneWidget);
      expect(store.bills, isEmpty); // Draft is never an implicit ledger write.
      await expectLater(root, matchesGoldenFile('goldens/review_$label.png'));
      await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();
      await AsrEngine.dispose(); await pcm.close(); store.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
