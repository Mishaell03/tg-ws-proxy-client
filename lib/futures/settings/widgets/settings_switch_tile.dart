import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: colors.primary,
      title: Text(
        title,
        style: AppText.regular_18a.copyWith(
          fontSize: 14,
          color: colors.text,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
