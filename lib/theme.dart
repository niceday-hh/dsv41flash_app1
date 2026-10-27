import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// 品牌色板：5 套主题色，iOS 风格的柔和渐变搭配。
const List<List<Color>> kAccents = <List<Color>>[
  <Color>[Color(0xFF6C5CE7), Color(0xFF9B8CFF)], // 靛蓝紫
  <Color>[Color(0xFFFF6B81), Color(0xFFFFA07A)], // 珊瑚粉
  <Color>[Color(0xFF0FB795), Color(0xFF4FE0B0)], // 薄荷绿
  <Color>[Color(0xFF2D9CDB), Color(0xFF56CCF2)], // 海洋蓝
  <Color>[Color(0xFFE39A1C), Color(0xFFFFC94D)], // 暖阳金
];

const List<String> kAccentNames = <String>['星夜紫', '珊瑚粉', '薄荷绿', '海盐蓝', '暖阳金'];

/// 字体回退链：优先 iOS/macOS 的系统字体，其次 Android / Web 常见中文字体。
const List<String> kFontFallback = <String>[
  'SF Pro Display',
  'SF Pro Text',
  '-apple-system',
  'PingFang SC',
  'HarmonyOS Sans SC',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Microsoft YaHei',
  'Roboto',
];

/// 圆角体系：全局只使用这四档，避免 9/12/22/26/28 混用造成“拼接感”。
class R {
  const R._();
  static const double s = 10; // 小标签、chip
  static const double m = 14; // 输入框、图标底
  static const double l = 20; // 按钮、次级卡片
  static const double xl = 28; // 主卡片
}

/// 分类色的统一“降噪”处理：压低饱和度、轻微提亮，
/// 让 40+ 个分类放在一起时不至于糖果色过载。
Color soften(Color c, {double sat = 0.72, double light = 0.04}) {
  final HSLColor hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation((hsl.saturation * sat).clamp(0.0, 1.0))
      .withLightness((hsl.lightness + light).clamp(0.0, 1.0))
      .toColor();
}

class Palette {
  final bool dark;
  final Color bg;
  final Color bgAlt;
  final Color card;
  final Color cardSoft;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color accent;
  final Color accent2;
  final Color expense;
  final Color income;

  const Palette({
    required this.dark,
    required this.bg,
    required this.bgAlt,
    required this.card,
    required this.cardSoft,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.accent,
    required this.accent2,
    required this.expense,
    required this.income,
  });

  factory Palette.of(bool dark, int accentIndex) {
    final pair = kAccents[accentIndex % kAccents.length];
    if (dark) {
      return Palette(
        dark: true,
        bg: const Color(0xFF0B0C14),
        bgAlt: const Color(0xFF14151F),
        card: const Color(0xFF1A1C2B),
        cardSoft: const Color(0xFF232538),
        ink: const Color(0xFFF3F4F9),
        ink2: const Color(0xFF9AA0B8),
        ink3: const Color(0xFF737A93),
        line: const Color(0xFF2C2F44),
        accent: pair[0],
        accent2: pair[1],
        expense: const Color(0xFFFF6E8A),
        income: const Color(0xFF2BD9A4),
      );
    }
    return Palette(
      dark: false,
      bg: const Color(0xFFF4F5FA),
      bgAlt: const Color(0xFFEDEEF7),
      card: const Color(0xFFFFFFFF),
      cardSoft: const Color(0xFFF6F6FB),
      ink: const Color(0xFF14151F),
      ink2: const Color(0xFF878CA3),
      ink3: const Color(0xFFB3B7C9),
      line: const Color(0xFFEDEDF5),
      accent: pair[0],
      accent2: pair[1],
      expense: const Color(0xFFF4576E),
      income: const Color(0xFF14C08A),
    );
  }

  LinearGradient get gradient => LinearGradient(
        colors: <Color>[accent, accent2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get gradientDiagonal => LinearGradient(
        colors: <Color>[accent2, accent],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );

  /// 卡片柔和阴影（iOS 风格：低透明度、大扩散）
  List<BoxShadow> get shadow => dark
      ? <BoxShadow>[
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10)),
        ]
      : <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2A2E50).withOpacity(0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF2A2E50).withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];

  List<BoxShadow> get accentGlow => <BoxShadow>[
        BoxShadow(color: accent.withOpacity(dark ? 0.42 : 0.30), blurRadius: 26, offset: const Offset(0, 12)),
      ];

  /// 深色模式下卡片与背景对比偏弱，用 1px 高光描边勾出边界
  Border? get hairline =>
      dark ? Border.all(color: Colors.white.withOpacity(0.065), width: 1) : null;
}

/// 全局文字样式助手
class T {
  static TextStyle h1(Palette p) =>
      TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.8, height: 1.1);
  static TextStyle h2(Palette p) =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.4);
  static TextStyle title(Palette p) => TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink);
  static TextStyle body(Palette p) => TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink);
  static TextStyle sub(Palette p) =>
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.ink2, letterSpacing: 0.1);
  static TextStyle num(Palette p, double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: p.ink,
        letterSpacing: -1.2,
        height: 1.05,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}

ThemeData buildTheme(Palette p) {
  final ColorScheme scheme = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.accent,
    onPrimary: Colors.white,
    secondary: p.accent2,
    onSecondary: Colors.white,
    error: p.expense,
    onError: Colors.white,
    surface: p.card,
    onSurface: p.ink,
    background: p.bg,
    onBackground: p.ink,
  );
  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withOpacity(0.25),
      selectionHandleColor: p.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  final TextTheme tt = base.textTheme;
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamilyFallback: kFontFallback);
  return base.copyWith(
    textTheme: TextTheme(
      displayLarge: f(tt.displayLarge),
      displayMedium: f(tt.displayMedium),
      displaySmall: f(tt.displaySmall),
      headlineLarge: f(tt.headlineLarge),
      headlineMedium: f(tt.headlineMedium),
      headlineSmall: f(tt.headlineSmall),
      titleLarge: f(tt.titleLarge),
      titleMedium: f(tt.titleMedium),
      titleSmall: f(tt.titleSmall),
      bodyLarge: f(tt.bodyLarge),
      bodyMedium: f(tt.bodyMedium),
      bodySmall: f(tt.bodySmall),
      labelLarge: f(tt.labelLarge),
      labelMedium: f(tt.labelMedium),
      labelSmall: f(tt.labelSmall),
    ),
  );
}
