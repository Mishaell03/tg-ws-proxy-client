import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncher {
  const UrlLauncher._();

  static Future<bool> openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      debugPrint('UrlLauncher: некорректная ссылка: $url');
      return false;
    }

    if (!uri.hasScheme) {
      debugPrint('UrlLauncher: у ссылки нет схемы: $url');
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('UrlLauncher: ссылка $url\nошибка: $error');
      return false;
    }
  }

  /// Opens a Telegram proxy link in the installed client. If no Telegram URI
  /// handler is available (or launching it fails), opens the equivalent
  /// https://t.me/proxy link in the default browser.
  static Future<bool> openTelegramProxy(String url) async {
    final telegramUri = Uri.tryParse(url);
    if (telegramUri == null ||
        telegramUri.scheme != 'tg' ||
        telegramUri.host != 'proxy') {
      debugPrint('UrlLauncher: invalid Telegram proxy URL: $url');
      return false;
    }

    var canTryDirect = true;
    if (!kIsWeb && Platform.isWindows) {
      canTryDirect = await _hasWindowsTelegramHandler();
    }
    if (canTryDirect && await openExternalUrl(url)) {
      return true;
    }

    final browserUri = Uri.https('t.me', '/proxy', telegramUri.queryParameters);
    return openExternalUrl(browserUri.toString());
  }

  static Future<bool> _hasWindowsTelegramHandler() async {
    const registryPaths = <String>[
      r'HKCU\Software\Classes\tg\shell\open\command',
      r'HKCR\tg\shell\open\command',
    ];
    for (final path in registryPaths) {
      try {
        final result = await Process.run('reg.exe', [
          'query',
          path,
          '/ve',
        ], runInShell: false);
        if (result.exitCode == 0) return true;
      } catch (_) {
        // Try the next registry location, then use the browser fallback.
      }
    }
    return false;
  }
}
