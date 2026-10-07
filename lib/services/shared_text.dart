import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Text other apps share to this one, like a note sent from the Android
/// share sheet. iOS needs a Share Extension for that, so there the note is
/// pasted instead.
class SharedText {
  SharedText._();

  static const MethodChannel _channel =
      MethodChannel('gym_progression/shared_text');

  /// Calls [onText] with the text shared at launch, then with each text
  /// shared while the app runs.
  static Future<void> listen(void Function(String text) onText) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    Future<void> take() async {
      final text = await _channel.invokeMethod<String>('takeSharedText');
      if (text != null && text.trim().isNotEmpty) {
        onText(text);
      }
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedTextReceived') {
        await take();
      }
    });
    await take();
  }
}
