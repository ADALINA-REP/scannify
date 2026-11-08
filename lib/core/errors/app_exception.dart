/// Base exception for all domain and infrastructure failures in Scannify.
sealed class AppException implements Exception {
  const AppException({required this.message, this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

/// Thrown when local database (Hive CE) initialization, read, write, or migration fails.
final class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.cause,
  });
}

/// Thrown when receipt validation fails (e.g., negative amount, empty merchant).
final class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.cause,
  });
}

/// Thrown when OCR extraction or parsing encounters an unrecoverable failure.
final class OcrException extends AppException {
  const OcrException({
    required super.message,
    super.code = 'OCR_ERROR',
    super.cause,
  });
}

/// Thrown when AdMob initialization or rewarded ad lifecycle fails.
final class MonetizationException extends AppException {
  const MonetizationException({
    required super.message,
    super.code = 'MONETIZATION_ERROR',
    super.cause,
  });
}
