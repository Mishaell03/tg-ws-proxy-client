import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tg_proxy/core/conrtrollers/theme_controller.dart';
import 'package:tg_proxy/futures/root/proxy_root_page.dart';
import 'package:tg_proxy/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(500, 700),
      minimumSize: Size(360, 560),
      center: true,
      title: 'Telegram proxy',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(TelegramProxyApp(themeController: ThemeController()..load()));
}

class TelegramProxyApp extends StatelessWidget {
  const TelegramProxyApp({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeController.themeMode,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        home: ProxyRootPage(themeController: themeController),
      ),
    );
  }
}
