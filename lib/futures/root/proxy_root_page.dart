import 'package:flutter/material.dart';
import 'package:tg_proxy/core/conrtrollers/theme_controller.dart';
import 'package:tg_proxy/futures/home/home_page.dart' as home;
import 'package:tg_proxy/futures/settings/proxy_page.dart' as settings;

const double kWideLayoutBreakpoint = 800;

class ProxyRootPage extends StatefulWidget {
  const ProxyRootPage({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  State<ProxyRootPage> createState() => _ProxyRootPageState();
}

class _ProxyRootPageState extends State<ProxyRootPage> {
  bool _showSettings = false;

  void openSettings() {
    setState(() {
      _showSettings = true;
    });
  }

  void closeSettings() {
    setState(() {
      _showSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideLayoutBreakpoint;

        if (!wide) {
          if (_showSettings) {
            return settings.ProxyPage(
              themeController: widget.themeController,
              onBack: closeSettings,
            );
          }
          return home.ProxyPage(
            themeController: widget.themeController,
            onSettings: openSettings,
          );
        }

        return Row(
          children: [
            Expanded(
              child: home.ProxyPage(
                themeController: widget.themeController,
                embedded: true,
              ),
            ),
            // VerticalDivider(),
            Expanded(
              child: settings.ProxyPage(
                themeController: widget.themeController,
                embedded: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
