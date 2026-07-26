import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';
import 'package:tg_proxy/core/conrtrollers/proxy_controller.dart';
import 'package:tg_proxy/core/widgets/animation_button.dart';
import 'package:tg_proxy/futures/settings/proxy_settings.dart';
import 'package:tg_proxy/futures/settings/widgets/settings_section.dart';
import 'package:tg_proxy/futures/settings/widgets/settings_switch_tile.dart';
import 'package:tg_proxy/futures/settings/widgets/settings_text_field.dart';
import 'package:tg_proxy/l10n/app_localizations.dart';

class ProxySettingsForm extends StatefulWidget {
  const ProxySettingsForm({
    required this.settings,
    required this.saving,
    required this.onSave,
    super.key,
  });

  final ProxySettings settings;
  final bool saving;
  final Future<void> Function(ProxySettings settings) onSave;

  @override
  State<ProxySettingsForm> createState() => _ProxySettingsFormState();
}

class _ProxySettingsFormState extends State<ProxySettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _secret;
  late final TextEditingController _dcIp;
  late final TextEditingController _bufferKb;
  late final TextEditingController _poolSize;
  late final TextEditingController _cfDomains;
  late final TextEditingController _workerDomains;
  late final TextEditingController _keepalive;
  late bool _cfProxy;
  late bool _forceTestDc;
  bool _normalizingSecret = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController();
    _port = TextEditingController();
    _secret = TextEditingController();
    _dcIp = TextEditingController();
    _bufferKb = TextEditingController();
    _poolSize = TextEditingController();
    _cfDomains = TextEditingController();
    _workerDomains = TextEditingController();
    _keepalive = TextEditingController();
    _secret.addListener(_keepSecretPrefix);
    _load(widget.settings);
  }

  @override
  void didUpdateWidget(covariant ProxySettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _load(widget.settings);
    }
  }

  void _load(ProxySettings settings) {
    _host.text = settings.host;
    _port.text = settings.port.toString();
    _secret.text = _displaySecret(settings.secret);
    _dcIp.text = settings.dcIp.join('\n');
    _bufferKb.text = settings.bufferKb.toString();
    _poolSize.text = settings.poolSize.toString();
    _cfDomains.text = settings.cfProxyDomains.join('\n');
    _workerDomains.text = settings.cfWorkerDomains.join('\n');
    _keepalive.text = settings.wsKeepaliveInterval.toString();
    _cfProxy = settings.cfProxy;
    _forceTestDc = settings.forceTestDc;
  }

  @override
  void dispose() {
    _secret.removeListener(_keepSecretPrefix);
    for (final controller in <TextEditingController>[
      _host,
      _port,
      _secret,
      _dcIp,
      _bufferKb,
      _poolSize,
      _cfDomains,
      _workerDomains,
      _keepalive,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String value) => value
      .replaceAll(';', '\n')
      .replaceAll(',', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  String _stripSecretPrefix(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('dd') ? trimmed.substring(2) : trimmed;
  }

  String _displaySecret(String value) => 'dd${_stripSecretPrefix(value)}';

  void _keepSecretPrefix() {
    if (_normalizingSecret) return;
    final value = _secret.text;
    if (value.toLowerCase().startsWith('dd')) return;

    _normalizingSecret = true;
    final next = _displaySecret(value);
    _secret.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _normalizingSecret = false;
  }

  String? _required(String? value, AppLocalizations t) =>
      value == null || value.trim().isEmpty ? t.validationRequired : null;

  String? _integer(String? value, int min, int max, AppLocalizations t) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < min || parsed > max
        ? t.validationRange(min, max)
        : null;
  }

  Future<void> _generateSecret() async {
    final secret = await ProxyController.generateSecret();
    if (mounted) {
      setState(() => _secret.text = _displaySecret(secret));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSave(
      ProxySettings(
        host: _host.text.trim(),
        port: int.parse(_port.text),
        secret: _stripSecretPrefix(_secret.text),
        dcIp: _lines(_dcIp.text),
        bufferKb: int.parse(_bufferKb.text),
        poolSize: int.parse(_poolSize.text),
        cfProxy: _cfProxy,
        cfProxyDomains: _lines(_cfDomains.text),
        cfWorkerDomains: _lines(_workerDomains.text),
        forceTestDc: _forceTestDc,
        wsKeepaliveInterval: int.parse(_keepalive.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = context.colors;
    final numberInput = <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
    ];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            title: t.listenerSection,
            children: [
              _AdaptivePair(
                first: SettingsTextField(
                  controller: _host,
                  label: t.hostLabel,
                  validator: (value) => _required(value, t),
                ),
                second: SettingsTextField(
                  controller: _port,
                  label: t.portLabel,
                  keyboardType: TextInputType.number,
                  inputFormatters: numberInput,
                  validator: (value) => _integer(value, 1, 65535, t),
                ),
              ),
              const SizedBox(height: 12),
              SettingsTextField(
                controller: _secret,
                label: t.secretLabel,
                suffixIcon: IconButton(
                  onPressed: _generateSecret,
                  tooltip: t.generateSecret,
                  icon: Icon(Icons.autorenew_rounded, color: colors.primary),
                ),
                maxLength: 34,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-FdD]')),
                ],
                validator: (value) =>
                    RegExp(r'^dd[0-9a-fA-F]{32}$').hasMatch(value ?? '')
                    ? null
                    : t.validationSecret,
              ),
            ],
          ),
          SettingsSection(
            title: t.telegramDataCentersSection,
            children: [
              SettingsTextField(
                controller: _dcIp,
                label: t.dcIpLabel,
                minLines: 4,
                maxLines: 8,
                validator: (value) => _required(value, t),
              ),
            ],
          ),
          SettingsSection(
            title: t.websocketBridgeSection,
            children: [
              _AdaptivePair(
                first: SettingsTextField(
                  controller: _bufferKb,
                  label: t.bufferKbLabel,
                  keyboardType: TextInputType.number,
                  inputFormatters: numberInput,
                  validator: (value) => _integer(value, 4, 16384, t),
                ),
                second: SettingsTextField(
                  controller: _poolSize,
                  label: t.poolSizeLabel,
                  keyboardType: TextInputType.number,
                  inputFormatters: numberInput,
                  validator: (value) => _integer(value, 0, 32, t),
                ),
              ),
              const SizedBox(height: 12),
              SettingsTextField(
                controller: _keepalive,
                label: t.keepaliveLabel,
                keyboardType: TextInputType.number,
                inputFormatters: numberInput,
                validator: (value) => _integer(value, 0, 3600, t),
              ),
            ],
          ),
          SettingsSection(
            title: t.cloudflareSection,
            children: [
              SettingsSwitchTile(
                title: t.cloudflareFallback,
                value: _cfProxy,
                onChanged: (value) => setState(() => _cfProxy = value),
              ),
              if (_cfProxy) ...[
                SettingsTextField(
                  controller: _cfDomains,
                  label: t.cloudflareDomainsLabel,
                  minLines: 2,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                SettingsTextField(
                  controller: _workerDomains,
                  label: t.workerDomainsLabel,
                  minLines: 2,
                  maxLines: 5,
                ),
              ],
              SettingsSwitchTile(
                title: t.forceTestDc,
                value: _forceTestDc,
                onChanged: (value) => setState(() => _forceTestDc = value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppAnimationButton(
            onPressed: widget.saving ? null : _submit,
            color: colors.primary,
            colorBg: colors.primary.withValues(alpha: 0.08),
            horizontal: 18,
            vertical: 13,
            borderRadius: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.saving
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(Icons.save_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  t.saveSettings,
                  style: AppText.bold_19.copyWith(
                    fontSize: 15,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptivePair extends StatelessWidget {
  const _AdaptivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
