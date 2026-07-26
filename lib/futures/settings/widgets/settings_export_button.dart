import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';
import 'package:tg_proxy/core/widgets/animation_button.dart';

class SettingsExportButton extends StatelessWidget {
  const SettingsExportButton({
    required this.exporting,
    required this.text,
    required this.onPressed,
    super.key,
  });

  final bool exporting;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppAnimationButton(
      onPressed: exporting ? null : onPressed,
      color: colors.primary,
      colorBg: colors.primary.withValues(alpha: 0.08),
      horizontal: 18,
      vertical: 13,
      borderRadius: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          exporting
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : Icon(Icons.download_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Text(
            text,
            style: AppText.bold_19.copyWith(
              fontSize: 15,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
