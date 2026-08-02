import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProxyController {
  static const MethodChannel _channel = MethodChannel('proxy');
  static final _DesktopProxyController _desktop = _DesktopProxyController();

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static Future<void> start() =>
      _isDesktop ? _desktop.start() : _channel.invokeMethod<void>('start');

  static Future<void> stop() =>
      _isDesktop ? _desktop.stop() : _channel.invokeMethod<void>('stop');

  static Future<Map<String, dynamic>> getSettings() => _isDesktop
      ? _desktop.getSettings()
      : _channel
            .invokeMapMethod<String, dynamic>('getSettings')
            .then((value) => Map<String, dynamic>.from(value ?? {}));

  static Future<Map<String, dynamic>> saveSettings(
    Map<String, dynamic> settings,
  ) => _isDesktop
      ? _desktop.saveSettings(settings)
      : _channel
            .invokeMapMethod<String, dynamic>('saveSettings', settings)
            .then((value) => Map<String, dynamic>.from(value ?? {}));

  static Future<Map<String, dynamic>> getStatus() => _isDesktop
      ? _desktop.getStatus()
      : _channel
            .invokeMapMethod<String, dynamic>('getStatus')
            .then((value) => Map<String, dynamic>.from(value ?? {}));

  static Future<String> generateSecret() => _isDesktop
      ? Future.value(_DesktopProxyController.randomSecret())
      : _channel
            .invokeMethod<String>('generateSecret')
            .then((value) => value ?? '');

  static Future<void> log(String message) => _isDesktop
      ? _desktop.log(message)
      : _channel.invokeMethod<void>('log', {'message': message});

  static Future<bool> exportLogs() => _isDesktop
      ? _desktop.exportLogs()
      : _channel
            .invokeMethod<bool>('exportLogs')
            .then((value) => value ?? false);

  static Future<bool> openTelegram(String proxyUrl) => _isDesktop
      ? _desktop.openTelegram(proxyUrl)
      : _channel
            .invokeMethod<bool>('openTelegram', {'url': proxyUrl})
            .then((value) => value ?? false);
}

class _DesktopProxyController {
  static const _settingsKey = 'desktop_proxy_settings';
  static const _enabledKey = 'desktop_proxy_enabled';
  static const _defaultSecret = '5ffd11a0e7765ff28e394636f2d29d17';

  Process? _process;
  Future<void>? _operation;
  String? _lastError;
  bool _starting = false;

  Map<String, dynamic> get _defaults => <String, dynamic>{
    'host': '127.0.0.1',
    'port': 1443,
    'secret': _defaultSecret,
    'dcIp': <String>[
      '1:149.154.175.53',
      '2:149.154.167.220',
      '3:149.154.175.100',
      '4:149.154.167.220',
      '5:91.108.56.130',
      '203:91.105.192.100',
    ],
    'bufferKb': 256,
    'poolSize': 2,
    'cfProxy': true,
    'cfProxyDomains': <String>[],
    'cfWorkerDomains': <String>[],
    'forceTestDc': false,
    'wsKeepaliveInterval': 30,
  };

  Directory get _bundleDirectory => File(Platform.resolvedExecutable).parent;
  Directory get _runtimeDirectory => Directory(
    '${_bundleDirectory.path}${Platform.pathSeparator}proxy_runtime',
  );
  File get _logFile => File(
    '${_applicationDataDirectory.path}${Platform.pathSeparator}tg-proxy.log',
  );
  Directory get _applicationDataDirectory {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['XDG_STATE_HOME'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return Directory('$base${Platform.pathSeparator}tg_proxy');
  }

  Future<void> start() => _serial(() async {
    if (_process != null) return;
    _lastError = null;
    final settings = await getSettings();
    final executable = Platform.isWindows
        ? '${_runtimeDirectory.path}${Platform.pathSeparator}python.exe'
        : '${_runtimeDirectory.path}${Platform.pathSeparator}bin${Platform.pathSeparator}python3';
    final script =
        '${_runtimeDirectory.path}${Platform.pathSeparator}proxy${Platform.pathSeparator}tg_ws_proxy.py';
    if (!File(executable).existsSync() || !File(script).existsSync()) {
      throw PlatformException(
        code: 'PROXY_RUNTIME_MISSING',
        message:
            'Proxy runtime is missing from the application bundle: $executable',
      );
    }

    await _ensurePortAvailable(
      settings['host'] as String,
      settings['port'] as int,
    );
    await _applicationDataDirectory.create(recursive: true);
    final args = <String>[
      '-u',
      script,
      '--host',
      settings['host'] as String,
      '--port',
      '${settings['port']}',
      '--secret',
      settings['secret'] as String,
      '--buf-kb',
      '${settings['bufferKb']}',
      '--pool-size',
      '${settings['poolSize']}',
      for (final dc in settings['dcIp'] as List<String>) ...['--dc-ip', dc],
      for (final domain in settings['cfProxyDomains'] as List<String>) ...[
        '--cfproxy-domain',
        domain,
      ],
      for (final domain in settings['cfWorkerDomains'] as List<String>) ...[
        '--cfproxy-worker-domain',
        domain,
      ],
      if (settings['cfProxy'] != true) '--no-cfproxy',
      if (settings['forceTestDc'] == true) '--force-test-dc',
    ];
    _starting = true;
    try {
      final process = await Process.start(
        executable,
        args,
        workingDirectory: _runtimeDirectory.path,
        mode: ProcessStartMode.normal,
        runInShell: false,
      );
      _process = process;
      process.stdout.transform(utf8.decoder).listen((text) => log(text.trim()));
      process.stderr.transform(utf8.decoder).listen((text) {
        final message = text.trim();
        if (_isProxyError(message)) _lastError = message;
        log(message);
      });
      process.exitCode.then((code) async {
        if (identical(_process, process)) {
          _process = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enabledKey, false);
          await log('Proxy process exited with code $code');
          if (code != 0 && (_lastError == null || _lastError!.isEmpty)) {
            _lastError = 'Proxy process exited with code $code';
          }
        }
      });
      await _waitUntilListening(process, settings);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      _lastError = null;
      await log('Proxy process started (pid ${process.pid})');
    } on ProcessException catch (error) {
      throw PlatformException(
        code: 'PROXY_START_FAILED',
        message: error.message,
      );
    } finally {
      _starting = false;
    }
  });

  Future<void> _ensurePortAvailable(String host, int port) async {
    ServerSocket? probe;
    try {
      probe = await ServerSocket.bind(host, port, shared: false);
    } on SocketException catch (error) {
      final code = error.osError?.errorCode;
      if (code == 10048 || code == 98 || code == 48) {
        throw PlatformException(
          code: 'PORT_IN_USE',
          message: 'Port $port is already in use',
          details: port,
        );
      }
      throw PlatformException(
        code: 'PROXY_START_FAILED',
        message: 'Cannot listen on $host:$port: ${error.message}',
      );
    } finally {
      await probe?.close();
    }
  }

  bool _isProxyError(String message) {
    if (message.isEmpty) return false;
    return RegExp(
          r'(^|\n).*\b(ERROR|CRITICAL)\b',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(message) ||
        message.contains('Traceback (most recent call last)') ||
        message.contains('Address already in use') ||
        message.contains('WinError 10048');
  }

  Future<void> _waitUntilListening(
    Process process,
    Map<String, dynamic> settings,
  ) async {
    final configuredHost = settings['host'] as String;
    final host = configuredHost == '0.0.0.0'
        ? '127.0.0.1'
        : configuredHost == '::'
        ? '::1'
        : configuredHost;
    final port = settings['port'] as int;
    for (var attempt = 0; attempt < 25; attempt++) {
      if (!identical(_process, process)) break;
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(milliseconds: 200),
        );
        await socket.close();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    if (identical(_process, process)) {
      _process = null;
      process.kill();
    }
    final details = _lastError;
    throw PlatformException(
      code: 'PROXY_START_FAILED',
      message: details == null || details.isEmpty
          ? 'Proxy did not start listening on $host:$port'
          : 'Proxy did not start: $details',
    );
  }

  Future<void> stop() => _serial(() async {
    final process = _process;
    _process = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await log('Proxy process stopped');
  });

  Future<T> _serial<T>(Future<T> Function() action) async {
    while (_operation != null) {
      await _operation;
    }
    final completer = action();
    _operation = completer.then<void>((_) {}, onError: (_) {});
    try {
      return await completer;
    } finally {
      _operation = null;
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) {
      final values = _validate(_defaults);
      await prefs.setString(_settingsKey, jsonEncode(values));
      return values;
    }
    try {
      return _validate(<String, dynamic>{..._defaults, ...jsonDecode(raw)});
    } catch (_) {
      final values = _validate(_defaults);
      await prefs.setString(_settingsKey, jsonEncode(values));
      return values;
    }
  }

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> input) async {
    final values = _validate(<String, dynamic>{
      ...await getSettings(),
      ...input,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(values));
    if (_process != null) {
      await stop();
      await start();
    }
    return values;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = _process != null;
    final running = enabled && !_starting;
    if (!enabled && (prefs.getBool(_enabledKey) ?? false)) {
      await prefs.setBool(_enabledKey, false);
    }
    return <String, dynamic>{
      'enabled': enabled,
      'running': running,
      'starting': _starting,
      if (_lastError != null) 'error': _lastError,
    };
  }

  Map<String, dynamic> _validate(Map<String, dynamic> input) {
    Never invalid(String message) =>
        throw PlatformException(code: 'INVALID_SETTINGS', message: message);
    int number(String key, int fallback) =>
        (input[key] as num?)?.toInt() ??
        int.tryParse('${input[key]}') ??
        fallback;
    List<String> strings(String key) =>
        (input[key] as List<dynamic>? ?? const [])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList();

    final host = '${input['host']}'.trim();
    if (host.isEmpty) invalid('host must not be empty');
    final port = number('port', 1443);
    if (port < 1 || port > 65535) invalid('port must be between 1 and 65535');
    final secret = '${input['secret']}'.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(secret)) {
      invalid('secret must contain exactly 32 hex characters');
    }
    final dcIps = strings('dcIp');
    if (dcIps.isEmpty ||
        dcIps.any((value) => !RegExp(r'^-?\d+:.+').hasMatch(value))) {
      invalid('dcIp contains an invalid entry');
    }
    final bufferKb = number('bufferKb', 256);
    if (bufferKb < 4 || bufferKb > 16384) {
      invalid('bufferKb must be between 4 and 16384');
    }
    final poolSize = number('poolSize', 2);
    if (poolSize < 0 || poolSize > 32) {
      invalid('poolSize must be between 0 and 32');
    }
    final keepalive = number('wsKeepaliveInterval', 30);
    if (keepalive < 0 || keepalive > 3600) {
      invalid('wsKeepaliveInterval must be between 0 and 3600');
    }
    return <String, dynamic>{
      'host': host,
      'port': port,
      'secret': secret,
      'dcIp': dcIps,
      'bufferKb': bufferKb,
      'poolSize': poolSize,
      'cfProxy': input['cfProxy'] == true,
      'cfProxyDomains': strings('cfProxyDomains'),
      'cfWorkerDomains': strings('cfWorkerDomains'),
      'forceTestDc': input['forceTestDc'] == true,
      'wsKeepaliveInterval': keepalive,
    };
  }

  Future<void> log(String message) async {
    if (message.trim().isEmpty) return;
    await _applicationDataDirectory.create(recursive: true);
    await _logFile.writeAsString(
      '${DateTime.now().toIso8601String()}  $message\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<bool> exportLogs() async {
    if (!await _logFile.exists()) {
      throw PlatformException(
        code: 'LOG_NOT_FOUND',
        message: 'The log file does not exist yet',
      );
    }
    try {
      final home =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw const FileSystemException(
          'User profile directory is unavailable',
        );
      }
      final downloads = Directory('$home${Platform.pathSeparator}Downloads');
      await downloads.create(recursive: true);
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}-'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final destination = File(
        '${downloads.path}${Platform.pathSeparator}tg-proxy-logs-$stamp.log',
      );
      await _logFile.copy(destination.path);
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,${destination.path}']);
      }
      return true;
    } on PlatformException {
      rethrow;
    } catch (error) {
      throw PlatformException(
        code: 'EXPORT_FAILED',
        message: 'Could not export logs: $error',
      );
    }
  }

  Future<bool> openTelegram(String proxyUrl) async {
    if (!proxyUrl.startsWith('tg://proxy?')) return false;
    try {
      if (Platform.isWindows) {
        final result = await Process.run('rundll32.exe', [
          'url.dll,FileProtocolHandler',
          proxyUrl,
        ], runInShell: false);
        if (result.exitCode != 0) {
          throw ProcessException('rundll32.exe', const [], '${result.stderr}');
        }
        return true;
      }
      final command = Platform.isMacOS ? 'open' : 'xdg-open';
      final result = await Process.run(command, [proxyUrl]);
      return result.exitCode == 0;
    } catch (error) {
      throw PlatformException(
        code: 'TELEGRAM_OPEN_FAILED',
        message: 'Could not open Telegram: $error',
      );
    }
  }

  static String randomSecret() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
