import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';

class SettingsThemeButton extends StatelessWidget {
  const SettingsThemeButton({
    required this.themeMode,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final ThemeMode themeMode;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveMode = themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light
        : themeMode;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      color: context.colors.text,
      icon: Icon(
        switch (effectiveMode) {
          ThemeMode.dark => Icons.dark_mode_rounded,
          ThemeMode.light => Icons.light_mode_rounded,
          ThemeMode.system => Icons.light_mode_rounded,
        },
      ),
    );
  }
}
