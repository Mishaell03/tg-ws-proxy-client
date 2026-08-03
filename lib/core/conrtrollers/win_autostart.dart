// lib/core/conrtrollers/win_autostart.dart
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _valueName = 'TgWsProxy';

Future<bool> isAutostartEnabledRaw() async {
  final phKey = calloc<IntPtr>();
  final subKey = _runKeyPath.toNativeUtf16();
  try {
    final openResult = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      subKey,
      0,
      KEY_QUERY_VALUE,
      phKey,
    );
    if (openResult != ERROR_SUCCESS) return false;

    final hKey = phKey.value;
    final valueNamePtr = _valueName.toNativeUtf16();
    try {
      final queryResult = RegQueryValueEx(
        hKey,
        valueNamePtr,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
      );
      return queryResult == ERROR_SUCCESS;
    } finally {
      calloc.free(valueNamePtr);
      RegCloseKey(hKey);
    }
  } finally {
    calloc.free(subKey);
    calloc.free(phKey);
  }
}

Future<bool> setAutostartRaw(bool enabled) async {
  final phKey = calloc<IntPtr>();
  final subKey = _runKeyPath.toNativeUtf16();
  try {
    final openResult = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      subKey,
      0,
      KEY_SET_VALUE,
      phKey,
    );
    if (openResult != ERROR_SUCCESS) return false;

    final hKey = phKey.value;

    if (enabled) {
      final valueNamePtr = _valueName.toNativeUtf16();
      final exePath = '"${Platform.resolvedExecutable}" --autostart';
      final exePathPtr = exePath.toNativeUtf16();
      try {
        final setResult = RegSetValueEx(
          hKey,
          valueNamePtr,
          0,
          REG_SZ,
          exePathPtr.cast<Uint8>(),
          (exePath.length + 1) * 2,
        );
        RegCloseKey(hKey);
        return setResult == ERROR_SUCCESS;
      } finally {
        calloc.free(valueNamePtr);
        calloc.free(exePathPtr);
      }
    } else {
      final valueNamePtr = _valueName.toNativeUtf16();
      try {
        final delResult = RegDeleteValue(hKey, valueNamePtr);
        RegCloseKey(hKey);
        return delResult == ERROR_SUCCESS || delResult == ERROR_FILE_NOT_FOUND;
      } finally {
        calloc.free(valueNamePtr);
      }
    }
  } finally {
    calloc.free(subKey);
    calloc.free(phKey);
  }
}
