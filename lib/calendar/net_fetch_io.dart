import 'dart:async';
import 'dart:convert';
import 'dart:io';

const bool canFetch = true;

Future<String?> fetchText(String url, {int maxBytes = 256000}) async {
  final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.followRedirects = true;
      final HttpClientResponse res = await req.close();
      if (res.statusCode != 200) return null;
      final List<int> bytes = <int>[];
      await for (final List<int> chunk in res) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) return null;
      }
      return utf8.decode(bytes);
    })()
        .timeout(const Duration(seconds: 18));
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
