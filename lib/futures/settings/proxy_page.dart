import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';
import 'package:tg_proxy/core/conrtrollers/proxy_controller.dart';
import 'package:tg_proxy/core/conrtrollers/theme_controller.dart';
import 'package:tg_proxy/futures/settings/proxy_settings.dart';
import 'package:tg_proxy/futures/settings/proxy_settings_form.dart';
import 'package:tg_proxy/futures/settings/widgets/settings_export_button.dart';
import 'package:tg_proxy/futures/settings/widgets/settings_status_panel.dart';
import 'package:tg_proxy/futures/settings/widgets/settings_theme_button.dart';
import 'package:tg_proxy/l10n/app_localizations.dart';

class ProxyPage extends StatefulWidget {
  const ProxyPage({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> {
  ProxySettings? _settings;
  Map<String, dynamic> _status = const {};
  Timer? _statusTimer;
  bool _saving = false;
  bool _exporting = false;
  String? _loadError;

  bool get _enabled => _status['enabled'] == true;
  bool get _running => _status['running'] == true;

  @override
  void initState() {
    super.initState();
    _load();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        ProxyController.getSettings(),
        ProxyController.getStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _settings = ProxySettings.fromMap(values[0]);
        _status = values[1];
        _loadError = null;
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _loadError = error.message ?? error.code);
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await ProxyController.getStatus();
      if (mounted) setState(() => _status = status);
    } on PlatformException {
      // Keep the last known state while the Android process reconnects.
    }
  }

  Future<void> _save(ProxySettings settings) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      unawaited(ProxyController.log('UI requested settings save'));
      final saved = await ProxyController.saveSettings(settings.toMap());
      if (!mounted) return;
      setState(() => _settings = ProxySettings.fromMap(saved));
      _showMessage(_enabled ? t.settingsSavedRestarted : t.settingsSaved);
    } on PlatformException catch (error) {
      unawaited(ProxyController.log('Settings save failed: ${error.message}'));
      if (error.code == 'PORT_IN_USE') {
        final port = (error.details as num?)?.toInt() ?? 0;
        _showMessage(t.portAlreadyInUse(port), error: true);
      } else {
        _showMessage(error.message ?? error.code, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportLogs() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final exported = await ProxyController.exportLogs();
      if (exported) _showMessage(t.logsExported);
    } on PlatformException catch (error) {
      _showMessage(error.message ?? error.code, error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppText.regular_18a),
        backgroundColor: error ? colors.error : colors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        foregroundColor: colors.text,
        title: Text(
          t.settingsTitle,
          style: AppText.bold_24.copyWith(color: colors.text),
        ),
        actions: [
          SettingsThemeButton(
            themeMode: widget.themeController.themeMode,
            tooltip: t.themeTooltip,
            onPressed: () => widget.themeController.setThemeMode(
              widget.themeController.nextVisibleMode(
                MediaQuery.platformBrightnessOf(context),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _settings == null
            ? _SettingsLoading(error: _loadError, onRetry: _load)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SettingsStatusPanel(
                    enabled: _enabled,
                    running: _running,
                    activeText: t.proxyActive,
                    inactiveText: t.proxyInactive,
                    connectingText: t.connecting,
                  ),
                  const SizedBox(height: 16),
                  ProxySettingsForm(
                    settings: _settings!,
                    saving: _saving,
                    onSave: _save,
                  ),
                  const SizedBox(height: 18),
                  SettingsExportButton(
                    exporting: _exporting,
                    text: t.exportLogs,
                    onPressed: _exportLogs,
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = context.colors;

    if (error == null) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error!,
            textAlign: TextAlign.center,
            style: AppText.regular_18a.copyWith(color: colors.error),
          ),
          const SizedBox(height: 12),
          IconButton.filledTonal(
            onPressed: onRetry,
            tooltip: t.retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
