import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the phone's screen from dimming while a round is in progress.
///
/// Reference-counted: each in-round screen calls [acquire] in `initState` and
/// [release] in `dispose`. Rounds move between screens with
/// `pushReplacement`, where the next screen starts *before* the previous one
/// is disposed — counting keeps the flag on across that handover, where a
/// plain on/off pair would switch it off right after it was switched on.
abstract final class ScreenAwake {
  static const _channel = MethodChannel('com.impostor.impostor/secure');

  static int _holders = 0;

  @visibleForTesting
  static int get holderCount => _holders;

  static void acquire() {
    if (_holders++ == 0) _invoke('keepScreenOn');
  }

  static void release() {
    if (_holders == 0) return;
    if (--_holders == 0) _invoke('allowScreenOff');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // No native side (tests, non-Android platforms).
    }
  }
}
