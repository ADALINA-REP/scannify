import '../../domain/services/export_service.dart';

Future<void> dispatchPlatformExportDocument(GeneratedExportDocument document) {
  throw UnsupportedError(
    'Cannot dispatch export document without dart:io or dart:js_interop.',
  );
}
