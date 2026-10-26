/// 轻量网络抓取：只在移动端/桌面可用，Web 端返回 null。
import 'net_fetch_stub.dart' if (dart.library.io) 'net_fetch_io.dart' as impl;

bool get canFetch => impl.canFetch;

Future<String?> fetchText(String url, {int maxBytes = 256000}) =>
    impl.fetchText(url, maxBytes: maxBytes);
