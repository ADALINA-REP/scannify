import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/services/export_service.dart';

Future<void> dispatchPlatformExportDocument(
  GeneratedExportDocument document,
) async {
  try {
    final jsUint8Array = document.bytes.toJS;
    final blobParts = <JSAny>[jsUint8Array].toJS;
    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: document.format.mimeType),
    );
    final objectUrl = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = objectUrl
      ..download = document.fileName
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(objectUrl);
  } catch (e, stackTrace) {
    AppLogger.error(
      'ExportFileDispatcherWeb',
      'Failed to trigger browser file download.',
      e,
      stackTrace,
    );
    throw StorageException(
      message: 'Failed to download exported file in browser.',
      cause: e,
    );
  }
}
