import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_shell.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/common.dart';
import 'voice/asr_engine.dart' as asr;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const Bootstrap());
}

/// 启动引导：加载本地数据，同时展示开屏动画
class Bootstrap extends StatefulWidget {
  const Bootstrap({Key? key}) : super(key: key);

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> with WidgetsBindingObserver {
  final AppStore _store = AppStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    // 首帧渲染完成后再预热语音模型，不阻塞启动画面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (asr.AsrEngine.supported) unawaited(asr.AsrEngine.warmUp());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!asr.AsrEngine.supported) return;
    if (state == AppLifecycleState.resumed) {
      asr.AsrEngine.onAppResumed();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      asr.AsrEngine.onAppPaused();
    }
  }

  @override
  void didHaveMemoryPressure() {
    asr.AsrEngine.onMemoryPressure();
  }

  Future<void> _init() async {
    await _store.load();
    // 读取用户对语音模型的保留偏好
    asr.AsrEngine.keepInBackground = _store.keepVoiceModel;
    asr.AsrEngine.backgroundRetention = Duration(seconds: _store.voiceRetentionSeconds);
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (BuildContext ctx, Widget? _) {
        final Palette p = Palette.of(_store.darkMode, _store.accentIndex);
        return AppScope(
          palette: p,
          store: _store,
          child: MaterialApp(
            title: '鲸记账 · Whale Ledger',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(p),
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (BuildContext context, Widget? child) {
              return LayoutBuilder(
                builder: (BuildContext ctx2, BoxConstraints c) {
                  // 桌面 / 平板下用手机画幅呈现，保持移动端比例
                  if (c.maxWidth < 720) return child ?? const SizedBox.shrink();
                  final double h = (c.maxHeight - 48).clamp(480.0, 900.0);
                  const double w = 420;
                  final MediaQueryData mq = MediaQuery.of(ctx2);
                  return Container(
                    color: const Color(0xFF101018),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.6, -0.7),
                                radius: 1.4,
                                colors: <Color>[
                                  p.accent.withOpacity(0.22),
                                  const Color(0xFF101018),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(46),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 60,
                                offset: const Offset(0, 28),
                              ),
                            ],
                            border: Border.all(color: Colors.white.withOpacity(0.12), width: 6),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: MediaQuery(
                              data: mq.copyWith(size: Size(w, h)),
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              child: !_ready
                  ? _Splash(key: const ValueKey<String>('splash'), palette: p)
                  : const AppShell(key: ValueKey<String>('app')),
            ),
          ),
        );
      },
    );
  }
}

class _Splash extends StatefulWidget {
  final Palette palette;

  const _Splash({Key? key, required this.palette}) : super(key: key);

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final Animation<double> a = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[p.accent, p.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(a),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              alignment: Alignment.center,
              child: const Text(
                '鲸',
                style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: const Interval(0.3, 1)),
            child: const Text(
              '鲸记账',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: const Interval(0.5, 1)),
            child: Text(
              'WHALE LEDGER',
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
