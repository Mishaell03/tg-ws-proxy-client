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
}
