import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';

class SettingsStatusPanel extends StatelessWidget {
  const SettingsStatusPanel({
    required this.enabled,
    required this.running,
    required this.activeText,
    required this.inactiveText,
    required this.connectingText,
    super.key,
  });

  final bool enabled;
  final bool running;
  final String activeText;
  final String inactiveText;
  final String connectingText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusText = !enabled
        ? inactiveText
        : running
        ? activeText
        : connectingText;
    final statusColor = !enabled
        ? colors.gray
        : running
        ? colors.success
        : colors.warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primarySecond.withValues(alpha: context.isDark ? 0.32 : 0.18),
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.circle, size: 12, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusText,
                style: AppText.bold_19.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
