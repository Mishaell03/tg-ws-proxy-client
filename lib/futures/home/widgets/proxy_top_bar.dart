import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';

class ProxyTopBar extends StatelessWidget {
  const ProxyTopBar({
    required this.title,
    required this.subtitle,
    required this.settingsTooltip,
    required this.onSettings,
    super.key,
  });

  final String title;
  final String subtitle;
  final String settingsTooltip;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bold_24.copyWith(color: colors.text),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.regular_18a.copyWith(
                    fontSize: 12,
                    color: colors.text.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TopBarIcon(
            icon: Icons.tune_rounded,
            tooltip: settingsTooltip,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  const _TopBarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon));
}
