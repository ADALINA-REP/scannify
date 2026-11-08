import 'package:flutter/foundation.dart';

/// Privacy-conscious logger for Scannify.
///
/// Ensures sensitive receipt contents (merchant names, monetary amounts,
/// tax identifiers, phone numbers, or raw OCR text) are redacted before
/// any diagnostic message is emitted in debug mode, and suppresses verbose
/// logs in release builds.
class AppLogger {
  AppLogger._();

  static final RegExp _siretRegex = RegExp(r'\b\d{9,14}\b');
  static final RegExp _amountRegex = RegExp(
    r'(\b\d{1,3}(?:[\s.,]\d{3})*(?:[.,]\d{2})\s?(?:€|EUR|\$|USD)?\b)',
    caseSensitive: false,
  );
  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,3}\)?[\s.-]?){3,4}\d{2,4}',
  );

  /// Redacts potentially sensitive financial or personal patterns from [message].
  static String sanitize(String message) {
    return message
        .replaceAll(_siretRegex, '[REDACTED_ID]')
        .replaceAll(_amountRegex, '[REDACTED_AMOUNT]')
        .replaceAll(_phoneRegex, '[REDACTED_PHONE]');
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[SCANNIFY][INFO][$tag] ${sanitize(message)}');
    }
  }

  static void warning(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      final errPart = error != null
          ? ' | Error: ${sanitize(error.toString())}'
          : '';
      debugPrint('[SCANNIFY][WARN][$tag] ${sanitize(message)}$errPart');
    }
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      final errPart = error != null
          ? ' | Error: ${sanitize(error.toString())}'
          : '';
      debugPrint('[SCANNIFY][ERROR][$tag] ${sanitize(message)}$errPart');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: tag, maxFrames: 8);
      }
    }
  }
}
