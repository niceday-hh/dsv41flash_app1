import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/csv_file.dart';
import '../store.dart';
import '../voice/asr_engine.dart' as asr;
import '../theme.dart';
import '../ui/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final AppStore store = AppScope.storeOf(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 132),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: <Widget>[
          Text('我的', style: T.h1(p).copyWith(fontSize: 24)),
          const SizedBox(height: 16),
          _profileCard(context, p, store),
          const SizedBox(height: 18),
          SectionTitle(title: '外观'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: <Widget>[
                _tile(
                  p,
                  icon: Icons.dark_mode_rounded,
                  color: const Color(0xFF5C6BC0),
                  title: '深色模式',
                  subtitle: '夜间记账更护眼',
                  trailing: _IosSwitch(
                    value: store.darkMode,
                    onChanged: (bool v) {
                      HapticFeedback.selectionClick();
                      store.setDark(v);
                    },
                  ),
                ),
                Divider(height: 1, color: p.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: <Widget>[
                      _iconBox(const Color(0xFFFF8A65), Icons.palette_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('主题色', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
                            const SizedBox(height: 3),
                            Text(
                              kAccentNames[store.accentIndex],
                              style: TextStyle(fontSize: 11.5, color: p.ink3),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List<Widget>.generate(kAccents.length, (int i) {
                          final bool on = store.accentIndex == i;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              store.setAccent(i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(left: 7),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: kAccents[i]),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: on ? p.ink.withOpacity(0.55) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: on
                                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle(title: '记账偏好'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: <Widget>[
                _tile(
                  p,
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xFFFFB74D),
                  title: '记账提醒',
                  subtitle: '每晚 21:30 提醒我记账',
                  trailing: _IosSwitch(
                    value: store.reminder,
                    onChanged: (bool v) {
                      HapticFeedback.selectionClick();
                      store.setReminder(v);
                      showToast(context, v ? '已开启记账提醒' : '已关闭记账提醒', icon: Icons.notifications_rounded);
                    },
                  ),
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF4DB6AC),
                  title: '默认货币',
                  subtitle: '人民币 CNY',
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () => showToast(context, '当前版本仅支持人民币', icon: Icons.info_rounded),
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.visibility_off_rounded,
                  color: const Color(0xFF7E8CE0),
                  title: '隐藏金额',
                  subtitle: '公共场合保护隐私',
                  trailing: _IosSwitch(
                    value: store.hideAmounts,
                    onChanged: (bool v) {
                      HapticFeedback.selectionClick();
                      store.setHideAmounts(v);
                    },
                  ),
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.memory_rounded,
                  color: const Color(0xFF9B8CFF),
                  title: '后台保留语音模型',
                  subtitle: store.keepVoiceModel
                      ? '切回应用可直接说话 · 切出即停止录音'
                      : '切到后台立即释放内存',
                  trailing: _IosSwitch(
                    value: store.keepVoiceModel,
                    onChanged: (bool v) {
                      HapticFeedback.selectionClick();
                      store.setKeepVoiceModel(v);
                      asr.AsrEngine.keepInBackground = v;
                    },
                  ),
                ),
                if (store.keepVoiceModel) ...<Widget>[
                  Divider(height: 1, color: p.line),
                  _tile(
                    p,
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF7E8CE0),
                    title: '模型保留时长',
                    subtitle: '${store.voiceRetentionSeconds} 秒后释放模型',
                    trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                    onTap: () => _pickRetention(context, store),
                  ),
                ],
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.account_circle_rounded,
                  color: const Color(0xFF7E8CE0),
                  title: '昵称',
                  subtitle: store.userName,
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () => _editName(context, store),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle(title: '数据'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: <Widget>[
                _tile(
                  p,
                  icon: Icons.download_rounded,
                  color: const Color(0xFF5C9DFF),
                  title: '导出账单',
                  subtitle: '复制为 CSV 文本，共 ${store.totalCount} 笔',
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () => _exportCsv(context, store),
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.upload_file_rounded,
                  color: const Color(0xFF14C08A),
                  title: '导入账单',
                  subtitle: '粘贴 CSV 文本，自动识别分类',
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () => _pickCsvFile(context, store),
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.restore_rounded,
                  color: const Color(0xFF26C6DA),
                  title: '恢复演示数据',
                  subtitle: '重新生成一份示例账本',
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () async {
                    final bool? ok = await _confirm(context, '恢复演示数据？', '当前账单会被示例数据替换，此操作不可撤销。');
                    if (ok == true) {
                      store.restoreDemo();
                      if (ctxMounted(context)) showToast(context, '演示数据已恢复');
                    }
                  },
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.delete_outline_rounded,
                  color: p.expense,
                  title: '清空所有账单',
                  subtitle: '谨慎操作，无法恢复',
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () async {
                    final bool? ok = await _confirm(context, '清空所有账单？', '所有记账记录将被永久删除。');
                    if (ok == true) {
                      store.clearAll();
                      if (ctxMounted(context)) showToast(context, '账单已清空', icon: Icons.delete_rounded);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle(title: '关于'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: <Widget>[
                _tile(
                  p,
                  icon: Icons.info_outline_rounded,
                  color: const Color(0xFF90A4AE),
                  title: '版本',
                  subtitle: '鲸记账 v1.0.0',
                  trailing: Text('已是最新', style: TextStyle(fontSize: 11.5, color: p.ink3)),
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.code_rounded,
                  color: const Color(0xFF9B8CFF),
                  title: '开源仓库',
                  subtitle: 'github.com/niceday-hh/dsv41flash_app1',
                  trailing: Icon(Icons.open_in_new_rounded, size: 16, color: p.ink3),
                  onTap: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: 'https://github.com/niceday-hh/dsv41flash_app1'),
                    );
                    if (ctxMounted(context)) showToast(context, '仓库地址已复制', icon: Icons.link_rounded);
                  },
                ),
                Divider(height: 1, color: p.line),
                _tile(
                  p,
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFFF6B81),
                  title: '给个好评',
                  subtitle: '喜欢就用它记录每一天',
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink3),
                  onTap: () => showToast(context, '谢谢你的喜欢 ♥', icon: Icons.favorite_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: p.gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: p.accentGlow,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '鲸',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text('鲸记账 · Whale Ledger', style: TextStyle(fontSize: 12, color: p.ink2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '用 Flutter 打造 · Made with ♥',
                  style: TextStyle(fontSize: 10.5, color: p.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, Palette p, AppStore store) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[p.accent, p.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: p.accentGlow,
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.09)),
            ),
          ),
          Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      store.userName.characters.first,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          store.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '已坚持记账 ${store.activeDays} 天',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _editName(context, store),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '编辑',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    _profileStat('累计笔数', '${store.totalCount}'),
                    Container(width: 1, height: 22, color: Colors.white.withOpacity(0.18)),
                    _profileStat('记账天数', '${store.activeDays}'),
                    Container(width: 1, height: 22, color: Colors.white.withOpacity(0.18)),
                    _profileStat('本月预算', '¥${fmtAmount(store.monthlyBudget)}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStat(String label, String value) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _iconBox(Color color, IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }

  Widget _tile(
    Palette p, {
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            _iconBox(color, icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, AppStore store) async {
    final DateTime now = DateTime.now();
    String two(int v) => v < 10 ? '0$v' : '$v';
    final String name = '鲸记账_${now.year}${two(now.month)}${two(now.day)}.csv';
    final String csv = store.exportCsv();
    if (CsvFileService.supported) {
      final bool ok = await CsvFileService.save(name, csv);
      if (ok) {
        if (ctxMounted(context)) showToast(context, '已保存 $name', icon: Icons.download_done_rounded);
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: csv));
    if (ctxMounted(context)) {
      showToast(context, CsvFileService.supported ? '已复制到剪贴板（未选择保存位置）' : 'CSV 已复制到剪贴板',
          icon: Icons.copy_rounded);
    }
  }

  Future<void> _pickCsvFile(BuildContext context, AppStore store) async {
    if (!CsvFileService.supported) {
      await _importCsv(context, store);
      return;
    }
    final String? text = await CsvFileService.pick();
    if (!ctxMounted(context)) return;
    if (text == null || text.trim().isEmpty) return;
    await _applyImport(context, store, text);
  }

  Future<void> _applyImport(BuildContext context, AppStore store, String text) async {
    final Palette p = AppScope.paletteOf(context);
    final int? mode = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('导入方式', style: T.h2(p).copyWith(fontSize: 17)),
        content: Text('追加到现有账单，或替换全部账单？', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: Text('取消', style: TextStyle(color: p.ink2))),
          TextButton(onPressed: () => Navigator.pop(ctx, 2), child: Text('替换', style: TextStyle(color: p.expense, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, 1), child: Text('追加', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (mode == null || mode == 0) return;
    try {
      final int n = store.importCsv(text, replace: mode == 2);
      if (ctxMounted(context)) {
        showToast(context, n > 0 ? '成功导入 $n 笔账单' : '没有可导入的数据',
            icon: n > 0 ? Icons.check_circle_rounded : Icons.info_rounded);
      }
    } on FormatException catch (e) {
      if (ctxMounted(context)) showToast(context, '导入失败：${e.message}', icon: Icons.error_outline_rounded);
    } catch (_) {
      if (ctxMounted(context)) showToast(context, '导入失败：格式不正确', icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _pickRetention(BuildContext context, AppStore store) async {
    final Palette p = AppScope.paletteOf(context);
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('语音模型保留时长', style: T.h2(p).copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '切到后台后，模型在这段时间内保留，切回可直接说话。',
              style: TextStyle(fontSize: 11.5, color: p.ink3, height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final int sec in <int>[5, 10, 15, 30])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('$sec 秒', style: TextStyle(fontSize: 14, color: p.ink)),
                trailing: store.voiceRetentionSeconds == sec
                    ? Icon(Icons.check_circle_rounded, size: 19, color: p.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, sec),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    store.setVoiceRetention(picked);
    asr.AsrEngine.backgroundRetention = Duration(seconds: picked);
  }

  Future<void> _importCsv(BuildContext context, AppStore store) async {
    final TextEditingController ctrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final Palette p = AppScope.paletteOf(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('导入账单', style: T.h2(p).copyWith(fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '表头需包含：日期,类型,分类,金额,备注',
                  style: TextStyle(fontSize: 11.5, color: p.ink3, height: 1.5),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: p.cardSoft, borderRadius: BorderRadius.circular(14)),
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(fontSize: 11.5, color: p.ink, height: 1.5),
                    cursorColor: p.accent,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '日期,类型,分类,金额,备注\n2026/10/1 12:30,支出,餐饮,28,午饭',
                      hintStyle: TextStyle(fontSize: 11, color: p.ink3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) ctrl.text = data!.text!;
                  },
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.content_paste_rounded, size: 14, color: p.accent),
                      const SizedBox(width: 5),
                      Text('从剪贴板粘贴', style: TextStyle(fontSize: 12, color: p.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('导入', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await _applyImport(context, store, ctrl.text);
    }
  }

  Future<void> _editName(BuildContext context, AppStore store) async {
    final TextEditingController ctrl = TextEditingController(text: store.userName);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        final Palette p = AppScope.paletteOf(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('修改昵称', style: T.h2(p).copyWith(fontSize: 17)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 12,
            style: TextStyle(fontSize: 15, color: p.ink),
            decoration: InputDecoration(
              counterText: '',
              hintText: '给自己起个名字',
              hintStyle: TextStyle(color: p.ink3),
              filled: true,
              fillColor: p.cardSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text('保存', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      store.setName(name);
      if (ctxMounted(context)) showToast(context, '昵称已更新');
    }
  }

  Future<bool?> _confirm(BuildContext context, String title, String desc) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final Palette p = AppScope.paletteOf(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(title, style: T.h2(p).copyWith(fontSize: 17)),
          content: Text(desc, style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('确定', style: TextStyle(color: p.expense, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }
}

/// iOS 风格开关
class _IosSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _IosSwitch({Key? key, required this.value, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 48,
        height: 29,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: value ? p.gradient : null,
          color: value ? null : (p.dark ? const Color(0xFF2A2C3E) : const Color(0xFFE4E5EF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 5, offset: const Offset(0, 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
