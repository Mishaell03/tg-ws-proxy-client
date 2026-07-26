import 'package:flutter/services.dart';

class ProxyController {
  static const MethodChannel _channel = MethodChannel('proxy');

  static Future<void> start() => _channel.invokeMethod<void>('start');
  static Future<void> stop() => _channel.invokeMethod<void>('stop');

  static Future<Map<String, dynamic>> getSettings() async =>
      Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('getSettings') ?? {},
      );

  static Future<Map<String, dynamic>> saveSettings(
    Map<String, dynamic> settings,
  ) async => Map<String, dynamic>.from(
    await _channel.invokeMapMethod<String, dynamic>('saveSettings', settings) ??
        {},
  );

  static Future<Map<String, dynamic>> getStatus() async =>
      Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('getStatus') ?? {},
      );

  static Future<String> generateSecret() async =>
      await _channel.invokeMethod<String>('generateSecret') ?? '';

  static Future<void> log(String message) =>
      _channel.invokeMethod<void>('log', {'message': message});

  static Future<bool> exportLogs() async =>
      await _channel.invokeMethod<bool>('exportLogs') ?? false;

  static Future<bool> openTelegram(String proxyUrl) async =>
      await _channel.invokeMethod<bool>('openTelegram', {'url': proxyUrl}) ??
      false;
}
