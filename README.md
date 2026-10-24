# 鲸记账 · Whale Ledger

[![Release](https://img.shields.io/github/v/release/niceday-hh/dsv41flash_app1?label=release)](https://github.com/niceday-hh/dsv41flash_app1/releases)
[![Web](https://img.shields.io/badge/demo-online-6C5CE7)](https://niceday-hh.github.io/dsv41flash_app1/)

> 🌐 在线体验：**https://niceday-hh.github.io/dsv41flash_app1/**
> 📱 下载 APK：**https://github.com/niceday-hh/dsv41flash_app1/releases/latest**

一款用 **Flutter** 打造的时尚轻盈记账 App，整体视觉参考「鲨鱼记账」等主流账本，融合 iOS 17 风格的大圆角卡片、磨砂玻璃底栏、渐变主视觉与细腻的动效。

> Android APK 与 Web 版由同一套 Flutter 代码构建。

---

## ✨ 功能特性

| 模块 | 说明 |
| --- | --- |
| 明细（首页） | 本月支出 / 收入 / 结余总览卡片，月份切换，按日分组账单，左右滑动删除、点击查看详情 |
| 图表 | 环形分类占比（可点击切换查看）、近 6 个月消费趋势柱状图、分类排行榜、智能洞察 |
| 预算 | 月预算环形进度、超支预警、日均可用、分类预算管理 |
| 我的 | 深色模式、5 套主题色、昵称、记账提醒、CSV 导出、数据重置 |
| 记一笔 | 底部弹层 + 数字键盘，支出/收入切换、12 个分类、备注与日期选择 |
| 数据 | 本地持久化（`shared_preferences`），首次启动自动生成 6 个月演示账单 |

## 🎨 设计要点

- **iOS 风格**：大圆角（26–32dp）卡片、低透明度大扩散阴影、磨砂玻璃导航栏、SF 字体回退链（PingFang / HarmonyOS Sans）
- **动效**：
  - 开屏 Logo 弹入 + 淡入
  - 金额数字滚动（`TweenAnimationBuilder`）
  - 分类环形图扫描式生长、可点击选中高亮
  - 柱状图逐根生长（`Interval` 错峰）
  - 预算环分段渐变描边 + 端点高光
  - 账单列表错峰淡入上浮
  - 底部 Tab 图标弹性缩放、分段控件滑动指示器
  - 所有可点击元素带按压缩放反馈与触感震动
- **深色模式**：完整的深色调色板，非简单反色
- **响应式**：手机全屏；桌面浏览器自动以「手机画幅」居中呈现

## 📱 截图

| 首页 | 图表 | 预算 | 我的 |
| --- | --- | --- | --- |
| ![home](docs/screenshots/home.png) | ![stats](docs/screenshots/stats.png) | ![budget](docs/screenshots/budget.png) | ![settings](docs/screenshots/settings.png) |

## 🚀 本地运行

```bash
flutter pub get
flutter run                 # 连接手机 / 模拟器
flutter run -d chrome       # 浏览器预览
```

## 📦 构建

```bash
# Android APK（需自备 android/key.properties 与 keystore）
flutter build apk --release

# Web（GitHub Pages 路径）
flutter build web --release --web-renderer html --base-href /dsv41flash_app1/
rm -f build/web/flutter_service_worker.js   # 关闭 SW，避免 CDN 缓存导致白屏

# 一键发布（Pages + Release）
GITHUB_TOKEN=xxx ./scripts/deploy.sh
```

产物：

- APK：`build/app/outputs/flutter-apk/app-release.apk`
- Web：`build/web`

## 🗂 项目结构

```
lib/
├── main.dart              # 启动引导、主题、桌面画幅适配
├── app_shell.dart         # 4 个 Tab + 玻璃底栏 + 背景光晕
├── theme.dart             # 调色板 / 字体链 / ThemeData
├── models.dart            # Bill、CategoryDef、DayGroup
├── data.dart              # 分类定义与演示账单生成
├── store.dart             # 状态管理（ChangeNotifier + 本地持久化）
├── pages/                 # home / stats / budget / settings
└── ui/                    # common（通用组件）、charts（图表）、add_sheet（记账弹层）
```

## 🔧 技术栈

- Flutter 3.0 / Dart 2.17（无第三方 UI 库，图表全部自绘 `CustomPainter`）
- `shared_preferences` 本地存储
- `flutter_localizations` 中文本地化

## 📄 License

MIT
