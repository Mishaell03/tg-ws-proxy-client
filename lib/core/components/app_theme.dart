import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/theme.dart';

class AppTheme {
  const AppTheme._();

  static AppColorsAccessor of(BuildContext context) {
    return AppColorsAccessor(context);
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}

class AppColorsAccessor {
  final BuildContext context;

  const AppColorsAccessor(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ===== BACKGROUND =====
  Color get bg => isDark ? AppDarkColors.bg : AppLightColors.bg;

  Color get border => isDark ? AppDarkColors.border : AppLightColors.border;

  Color get primarySecond =>
      isDark ? AppDarkColors.primarySecond : AppLightColors.primarySecond;

  // ===== TEXT =====
  Color get text => isDark ? AppDarkColors.text : AppLightColors.text;

  // ===== STATUS =====
  Color get primary => AppColors.primary;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get gray => AppColors.gray;
  Color get transparent => AppColors.transparent;
}

extension AppThemeExtension on BuildContext {
  AppColorsAccessor get colors => AppTheme.of(this);

  bool get isDark => AppTheme.isDark(this);
}
