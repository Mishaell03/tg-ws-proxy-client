import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';
import 'package:tg_proxy/core/widgets/animation_button.dart';

class ProxyStatusLabel extends StatelessWidget {
  const ProxyStatusLabel({
    required this.isConnected,
    required this.isConnecting,
    required this.connectedText,
    required this.connectingText,
    required this.disconnectedText,
    required this.activeText,
    required this.inactiveText,
    required this.openTelegramText,
    required this.onOpenTelegram,
    super.key,
  });

  final bool isConnected;
  final bool isConnecting;
  final String connectedText;
  final String connectingText;
  final String disconnectedText;
  final String activeText;
  final String inactiveText;
  final String openTelegramText;
  final VoidCallback onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = isConnected;
    final buttonColor = enabled ? colors.primary : colors.gray;
    final statusText = isConnecting
        ? connectingText
        : isConnected
        ? activeText
        : inactiveText;
    final statusColor = isConnecting
        ? colors.warning
        : isConnected
        ? colors.success
        : colors.gray;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAnimationButton(
            onPressed: enabled ? onOpenTelegram : null,
            color: buttonColor,
            colorBg: buttonColor.withValues(alpha: 0.09),
            colorHover: colors.primary.withValues(alpha: 0.16),
            colorPressed: colors.primary.withValues(alpha: 0.24),
            horizontal: 22,
            vertical: 14,
            borderRadius: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_rounded, color: buttonColor),
                const SizedBox(width: 10),
                Text(
                  openTelegramText,
                  style: AppText.bold_19.copyWith(color: buttonColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: AppText.regular_18a.copyWith(color: statusColor),
          ),
          const SizedBox(height: 4),
          Text(
            isConnecting
                ? connectingText
                : isConnected
                ? connectedText
                : disconnectedText,
            textAlign: TextAlign.center,
            style: AppText.regular_18a.copyWith(
              fontSize: 12,
              color: colors.text.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
