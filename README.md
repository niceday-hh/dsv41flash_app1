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
| 我的 | 深色模式、5 套主题色、隐藏金额、昵称、记账提醒、**CSV 导入 / 导出**、数据重置 |
| 记一笔 | 底部弹层 + 数字键盘，**支持 + − 计算**、**常用备注快捷**、支出/收入切换、12 个分类、备注与日期 |
| 数据 | 本地持久化（`shared_preferences`），首次启动自动生成 6 个月演示账单 |

## 🆕 更新日志

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


## 🔐 签名与版本迭代（重要）

App 的升级安装要求**签名证书一致**：换 key 会导致已安装用户无法覆盖升级（必须先卸载）。

| 项目 | 值 |
| --- | --- |
| 证书 SHA-256 | `64:4C:DF:1A:C7:AB:B0:55:A4:96:D9:7B:A0:76:11:33:18:7D:25:62:8B:A8:61:AB:EF:12:3D:5F:89:63:6F:93` |
| Key Alias | `whale` |
| Keystore 类型 | PKCS12（store 与 key 密码相同） |
| 有效期 | 2026-10-24 ~ 2054-03-11 |

- 签名文件 `android/key.jks` 与 `android/key.properties` **不提交到仓库**（`.gitignore` 已排除）。
- CI 构建（`.github/workflows/android-release.yml`）从仓库 Secrets 读取：

| Secret 名称 | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w 0 android/key.jks` 的输出 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | key 密码（PKCS12 下与上面相同） |
| `ANDROID_KEY_ALIAS` | `whale` |

配置好后，推送 tag 即自动出包：

```bash
git tag v1.0.1 && git push origin v1.0.1
```

> ⚠️ 请把 `android/key.jks` 备份到密码管理器。**丢失后无法再发布可覆盖升级的新版本。**

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
