// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'TG Proxy';

  @override
  String get appSubtitle => 'Быстрое и безопасное подключение к Telegram';

  @override
  String get openTelegram => 'Открыть Telegram';

  @override
  String get telegramOpenFailed => 'Не удалось открыть Telegram';

  @override
  String get connecting => 'Подключение...';

  @override
  String portAlreadyInUse(int port) {
    return 'Порт $port уже занят другим приложением';
  }

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get proxyActive => 'Прокси активен';

  @override
  String get proxyInactive => 'Прокси неактивен';

  @override
  String get start => 'Включить';

  @override
  String get stop => 'Выключить';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get themeTooltip => 'Сменить тему';

  @override
  String get settingsSavedRestarted =>
      'Настройки сохранены. Прокси перезапущен.';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get logsExported => 'Логи экспортированы';

  @override
  String get retry => 'Повторить';

  @override
  String get exportLogs => 'Экспорт логов';

  @override
  String get connectionLinkSection => 'Ссылка подключения';

  @override
  String get copyConnectionLink => 'Копировать ссылку';

  @override
  String get connectionLinkCopied => 'Ссылка подключения скопирована';

  @override
  String get listenerSection => 'Слушатель';

  @override
  String get hostLabel => 'Хост';

  @override
  String get portLabel => 'Порт';

  @override
  String get secretLabel => 'Ключ';

  @override
  String get generateSecret => 'Сгенерировать ключ';

  @override
  String get validationRequired => 'Обязательное поле';

  @override
  String validationRange(int min, int max) {
    return 'Введите значение от $min до $max';
  }

  @override
  String get validationSecret =>
      'Ключ должен начинаться с dd и содержать 32 hex-символа после него';

  @override
  String get telegramDataCentersSection => 'Дата-центры Telegram';

  @override
  String get dcIpLabel => 'IP дата-центра';

  @override
  String get websocketBridgeSection => 'WebSocket-мост';

  @override
  String get bufferKbLabel => 'Буфер, КБ';

  @override
  String get poolSizeLabel => 'Размер пула';

  @override
  String get keepaliveLabel => 'Интервал keepalive';

  @override
  String get cloudflareSection => 'Cloudflare';

  @override
  String get cloudflareFallback => 'Резерв через Cloudflare';

  @override
  String get cloudflareDomainsLabel => 'Домены Cloudflare';

  @override
  String get workerDomainsLabel => 'Домены Worker';

  @override
  String get forceTestDc => 'Принудительно тестовый DC';

  @override
  String get saveSettings => 'Сохранить настройки';
}
