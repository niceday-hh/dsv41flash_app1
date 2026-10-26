import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calendar/calendar_data.dart';
import '../theme.dart';
import '../ui/common.dart';

/// 日期资料：在线更新法定假期与节气
class CalendarSettingsPage extends StatefulWidget {
  const CalendarSettingsPage({Key? key}) : super(key: key);

  @override
  State<CalendarSettingsPage> createState() => _CalendarSettingsPageState();
}

class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  final CalendarData _data = CalendarData.instance;
  late int _year;
  List<String> _result = <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _data.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _check() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _result = <String>[];
    });
    final List<String> r = await _data.check(_year);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = AppScope.paletteOf(context);
    final List<int> years = _data.years;
    final DateTime? updated = _data.checkedAt[_year];
    final List<String> papers = _data.papersOf(_year);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
              child: Row(
                children: <Widget>[
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration:
                          BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: p.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('日期资料', style: T.h1(p).copyWith(fontSize: 20)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
                children: <Widget>[
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.event_note_rounded, size: 16, color: p.accent),
                            const SizedBox(width: 6),
                            Text('覆盖年份',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          years.isEmpty ? '暂无资料' : years.map((int y) => '$y').join(' · '),
                          style: TextStyle(fontSize: 12, color: p.ink2, height: 1.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '内置 2025–2027 的节气与固定节日；法定放假与补班可通过下方按钮在线更新。',
                          style: TextStyle(fontSize: 11, color: p.ink3, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.sync_rounded, size: 17, color: p.ink2),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text('自动检查更新',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: p.ink)),
                                    const SizedBox(height: 3),
                                    Text(
                                      _data.online
                                          ? '打开应用时检查今年与明年，24 小时内最多一次'
                                          : '当前平台不支持联网更新',
                                      style: TextStyle(fontSize: 11, color: p.ink3),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _data.automatic,
                                activeColor: p.accent,
                                onChanged: _data.online
                                    ? (bool v) async {
                                        HapticFeedback.selectionClick();
                                        await _data.setAutomatic(v);
                                        if (mounted) setState(() {});
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: p.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(Icons.calendar_month_rounded, size: 17, color: p.ink2),
                                  const SizedBox(width: 10),
                                  Text('检查年份',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: p.ink)),
                                  const Spacer(),
                                  Segmented(
                                    labels: <String>[
                                      '${DateTime.now().year}',
                                      '${DateTime.now().year + 1}'
                                    ],
                                    index: _year == DateTime.now().year ? 0 : 1,
                                    compact: true,
                                    segWidth: 52,
                                    onChanged: (int i) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _year = DateTime.now().year + i;
                                        _result = <String>[];
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: Pressable(
                                  onTap: _busy ? null : _check,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: p.gradient,
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: p.accentGlow,
                                    ),
                                    alignment: Alignment.center,
                                    child: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.white),
                                          )
                                        : Text(
                                            '检查 $_year 年资料',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                ),
                              ),
                              if (updated != null) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  '上次检查：${updated.month}月${updated.day}日 '
                                  '${updated.hour.toString().padLeft(2, '0')}:'
                                  '${updated.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 10.5, color: p.ink3),
                                ),
                              ],
                              if (_result.isNotEmpty || (_data.messages[_year] ?? '').isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: p.cardSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    (_result.isNotEmpty
                                            ? _result
                                            : (_data.messages[_year] ?? '').split('\n'))
                                        .map((String s) => '· $s')
                                        .join('\n'),
                                    style: TextStyle(
                                        fontSize: 11, color: p.ink2, height: 1.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (papers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('公告来源',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink)),
                          const SizedBox(height: 6),
                          for (final String url in papers)
                            GestureDetector(
                              onTap: () async {
                                await Clipboard.setData(ClipboardData(text: url));
                                if (mounted) {
                                  showToast(context, '公告链接已复制',
                                      icon: Icons.link_rounded);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(
                                  url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10.5, color: p.accent),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '数据来源：holiday-cn（国务院公告整理）、香港天文台节气表。'
                    '更新只写入本地缓存，不上传任何账本数据。',
                    style: TextStyle(fontSize: 10.5, color: p.ink3, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
