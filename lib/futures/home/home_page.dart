import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tg_proxy/core/components/url_launcher.dart';
import 'package:tg_proxy/core/conrtrollers/proxy_controller.dart';
import 'package:tg_proxy/core/conrtrollers/theme_controller.dart';
import 'package:tg_proxy/futures/home/widgets/network_background.dart';
import 'package:tg_proxy/futures/home/widgets/proxy_central_orb.dart';
import 'package:tg_proxy/futures/home/widgets/proxy_status_label.dart';
import 'package:tg_proxy/futures/home/widgets/proxy_top_bar.dart';
import 'package:tg_proxy/futures/settings/proxy_settings.dart'
    as settings_model;
import 'package:tg_proxy/l10n/app_localizations.dart';

class ProxyPage extends StatefulWidget {
  const ProxyPage({
    required this.themeController,
    this.embedded = false,
    this.onSettings,
    super.key,
  });

  final ThemeController themeController;
  final bool embedded;
  final VoidCallback? onSettings;

  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> with TickerProviderStateMixin {
  late final AnimationController _networkController;
  late final AnimationController _pulseController;
  late final AnimationController _orbitController;
  Timer? _statusTimer;

  bool _enabled = false;
  bool _running = false;
  bool _changingState = false;
  String? _lastReportedError;

  bool get _connecting => _changingState || (_enabled && !_running);

  @override
  void initState() {
    super.initState();
    _networkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _refreshStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _networkController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await ProxyController.getStatus();
      if (!mounted) return;
      setState(() {
        _enabled = status['enabled'] == true;
        _running = status['running'] == true;
      });
      final error = status['errorCode'] == 'PORT_IN_USE'
          ? AppLocalizations.of(
              context,
            )!.portAlreadyInUse((status['errorPort'] as num?)?.toInt() ?? 1443)
          : status['error']?.toString();
      if (error != null && error.isNotEmpty && error != _lastReportedError) {
        _lastReportedError = error;
        _showError(error);
      }
    } on PlatformException {
      // Keep the last known state while the Android process reconnects.
    }
  }

  Future<void> _toggleProxy() async {
    if (_changingState) return;
    final t = AppLocalizations.of(context)!;
    setState(() => _changingState = true);
    try {
      if (_enabled) {
        unawaited(ProxyController.log('Central button requested proxy stop'));
        await ProxyController.stop();
      } else {
        unawaited(ProxyController.log('Central button requested proxy start'));
        await ProxyController.start();
      }
      await _refreshStatus();
    } on PlatformException catch (error) {
      if (error.code == 'PORT_IN_USE') {
        final port = (error.details as num?)?.toInt() ?? 0;
        _showError(t.portAlreadyInUse(port));
      } else {
        _showError(error.message ?? error.code);
      }
    } finally {
      if (mounted) setState(() => _changingState = false);
    }
  }

  void _openSettings() {
    widget.onSettings?.call();
  }

  Future<void> _openTelegram() async {
    if (!_enabled) return;

    try {
      final proxySettings = settings_model.ProxySettings.fromMap(
        await ProxyController.getSettings(),
      );
      final opened = await UrlLauncher.openTelegramProxy(
        _buildMtprotoProxyUrl(proxySettings),
      );
      if (!mounted) return;
      if (!opened) {
        _showError(AppLocalizations.of(context)!.telegramOpenFailed);
      }
    } on PlatformException catch (error) {
      _showError(error.message ?? error.code);
    }
  }

  String _buildMtprotoProxyUrl(settings_model.ProxySettings settings) {
    final server = settings.host == '0.0.0.0' ? '127.0.0.1' : settings.host;
    return Uri(
      scheme: 'tg',
      host: 'proxy',
      queryParameters: <String, String>{
        'server': server,
        'port': settings.port.toString(),
        'secret': 'dd${settings.secret}',
      },
    ).toString();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NetworkBackground(
              controller: _networkController,
              isConnected: _running,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ProxyTopBar(
                  title: t.appTitle,
                  subtitle: t.appSubtitle,
                  settingsTooltip: t.settingsTitle,
                  onSettings: widget.embedded ? null : _openSettings,
                ),
                const Spacer(flex: 2),
                ProxyCentralOrb(
                  pulseController: _pulseController,
                  orbitController: _orbitController,
                  isConnected: _running,
                  isConnecting: _connecting,
                  onPressed: _toggleProxy,
                ),
                const Spacer(flex: 2),
                ProxyStatusLabel(
                  isConnected: _running,
                  isConnecting: _connecting,
                  connectedText: t.connected,
                  connectingText: t.connecting,
                  disconnectedText: t.disconnected,
                  activeText: t.proxyActive,
                  inactiveText: t.proxyInactive,
                  openTelegramText: t.openTelegram,
                  onOpenTelegram: _openTelegram,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
