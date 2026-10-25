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
| 明细（首页） | 本月支出 / 收入 / 结余总览卡片，月份切换，按日分组账单；**搜索**、**点按编辑**、长按操作菜单、滑动删除（二次确认）、一键隐藏金额 |
| 图表 | **周 / 月 / 季 / 年** 四种周期、环形分类占比（可点击）、趋势柱状图（7 天 / 周 / 月 / 12 月自适应）、**分类排行钻取**、环比与智能洞察 |
| 洞察 | 7 类统计分析（环比 / 归因 / 频次×均额 / 周末节奏 / 集中度 / 周期账单 / 预算情景），含计算依据与关联账单 |
| 日历 | 月历热力图，按日查看收支明细 |
| 预算 | 月预算环形进度、超支预警、日均可用、分类预算管理 |
| 我的 | 深色模式、5 套主题色、隐藏金额、昵称、记账提醒、**CSV 文件导入 / 导出**、数据重置 |
| 记一笔 | 底部弹层 + 数字键盘，**支持 + − 计算**、**备注词云**（字号随频次变化）、**语音记账**、支出/收入切换、12 个分类、备注与日期 |
| 语音 | **完全离线**的中文语音记账：说「午饭二十八块」自动填入金额 / 分类 / 日期；模型随包内置，不联网、不上传 |
| 数据 | 本地持久化（`shared_preferences`），首次启动自动生成 6 个月演示账单 |

## 🆕 更新日志

### v1.3.0（补齐 3.1.4 的语音与文件能力）
- 新增 **离线语音记账**：内置 sherpa-onnx + 中文流式 Zipformer 模型（约 30MB，随 APK 打包）
  - 原生 16kHz 单声道 PCM 采集（Kotlin `AudioRecord` + EventChannel），无需第三方录音插件
  - 边说边出字，实时解析「昨天打车二十八块五」→ 金额 / 分类 / 日期 / 收支
  - 支持中文数字（「两千六百」）、角分（「十五块五」）、相对日期（今天/昨天/前天/大前天）、14 类目关键词推断
  - 全程本地推理，**不联网、不上传音频**
- 新增 **备注词云**：按历史使用频次排版，字号与色深随频次变化，点一下即填入
- 新增 **原生文件导入导出**：Android 通过系统文件选择器读写 CSV（`ACTION_CREATE_DOCUMENT` / `ACTION_OPEN_DOCUMENT`），其余平台自动回退到剪贴板
- 导入支持「追加 / 替换」两种模式，表头校验失败会给出明确提示
- 升级构建链：Flutter 3.24 + AGP 8.3 + Gradle 8.6 + SDK 34；APK 仅保留 `arm64-v8a` / `armeabi-v7a`，体积从 193MB 降到 112MB
- 底栏不透明度提升，修复内容穿透导致的可读性问题；各页底部留白统一

### v1.2.0（对齐 拾光账本 3.1.4 的能力）
- 新增 **消费日历**：月历热力格（按当日金额深浅着色）+ 当日明细、最高单日、弹指切换月份
- 新增 **消费洞察**：等长时段对比、变化来源、频次 × 单笔均额、周末/工作日日均、支出集中度（HHI）、疑似周期账单、月末预算情景
  - 每条结论可展开「计算依据」，并可查看**关联账单**（点进还能直接编辑）
  - 预算情景支持滑块模拟：下调后预测月末支出与结余
- 新增 **快捷入口**：长按底栏 `+` 呼出「记一笔 / 消费日历 / 消费洞察」
- 报表页的洞察卡改为可点击，直达完整洞察
- 趋势柱状图改为细柱 + 高亮当前最大值，视觉更清爽

### v1.1.0
- 新增 **搜索**：按备注 / 分类 / 金额检索，含分类快捷入口与最近记录
- 新增 **编辑账单**：点击账单直接改金额、分类、备注、日期；长按呼出操作菜单，删除需二次确认
- 报表升级为 **周 / 月 / 季 / 年** 四种周期，趋势图节点自适应，支持环比与「回到本期」
- 新增 **分类钻取**：点排行榜任意分类查看该分类明细
- 记账键盘支持 **加减运算**（输入 `12+8` 自动算 20），并推荐该分类的**常用备注**
- 新增 **隐藏金额**：首页眼睛图标一键打码，全局生效
- 新增 **CSV 导入**：粘贴文本即可导入，自动识别分类与日期
- 视觉细节：分段控件支持 4 段、分类网格重排、预算环渐变重绘

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

> 环境要求：**Flutter 3.24+**（Dart 3.5+）、JDK 17、Android SDK 34。语音模块依赖 `sherpa_onnx` 的原生库，需要真机或有麦克风的模拟器。

```bash
flutter pub get
flutter run                 # 连接手机 / 模拟器
flutter run -d chrome       # 浏览器预览
```

## 📦 构建

```bash
# Android APK（release 构建需自行配置签名）
flutter build apk --release --build-name=1.3.0 --build-number=4

# Web（GitHub Pages 路径）
flutter build web --release --web-renderer html --base-href /dsv41flash_app1/
rm -f build/web/flutter_service_worker.js   # 关闭 SW，避免 CDN 缓存导致白屏
rm -rf build/web/assets/assets/asr build/web/assets/packages/sherpa_onnx_web   # Web 版不含语音模型
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
