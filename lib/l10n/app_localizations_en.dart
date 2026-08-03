// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TG Proxy';

  @override
  String get appSubtitle => 'Fast and secure connection for Telegram';

  @override
  String get openTelegram => 'Open Telegram';

  @override
  String get telegramOpenFailed => 'Could not open Telegram';

  @override
  String get connecting => 'Connecting...';

  @override
  String portAlreadyInUse(int port) {
    return 'Port $port is already used by another application';
  }

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get proxyActive => 'Proxy Active';

  @override
  String get proxyInactive => 'Proxy Inactive';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeTooltip => 'Change theme';

  @override
  String get settingsSavedRestarted => 'Settings saved. Proxy restarted.';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get logsExported => 'Logs exported';

  @override
  String get retry => 'Retry';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get connectionLinkSection => 'Connection link';

  @override
  String get copyConnectionLink => 'Copy link';

  @override
  String get connectionLinkCopied => 'Connection link copied';

  @override
  String get listenerSection => 'Listener';

  @override
  String get hostLabel => 'Host';

  @override
  String get portLabel => 'Port';

  @override
  String get secretLabel => 'Secret';

  @override
  String get generateSecret => 'Generate secret';

  @override
  String get validationRequired => 'Required field';

  @override
  String validationRange(int min, int max) {
    return 'Enter a value from $min to $max';
  }

  @override
  String get validationSecret =>
      'Secret must start with dd and contain 32 hex characters after it';

  @override
  String get telegramDataCentersSection => 'Telegram data centers';

  @override
  String get dcIpLabel => 'DC IP';

  @override
  String get websocketBridgeSection => 'WebSocket bridge';

  @override
  String get bufferKbLabel => 'Buffer, KB';

  @override
  String get poolSizeLabel => 'Pool size';

  @override
  String get keepaliveLabel => 'Keepalive interval';

  @override
  String get cloudflareSection => 'Cloudflare';

  @override
  String get cloudflareFallback => 'Cloudflare fallback';

  @override
  String get cloudflareDomainsLabel => 'Cloudflare domains';

  @override
  String get workerDomainsLabel => 'Worker domains';

  @override
  String get forceTestDc => 'Force test DC';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get systemSection => 'System';

  @override
  String get launchAtStartup => 'Launch at Windows startup';

  @override
  String get autostartError => 'Failed to change autostart setting';
}
