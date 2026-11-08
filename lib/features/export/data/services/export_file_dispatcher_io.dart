import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/services/export_service.dart';

Future<void> dispatchPlatformExportDocument(
  GeneratedExportDocument document,
) async {
  File? tempFile;
  try {
    final tempDir = await getTemporaryDirectory();
    await _cleanupStaleExportTempFiles(tempDir);

    final safeName = document.fileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final filePath = '${tempDir.path}${Platform.pathSeparator}$safeName';
    tempFile = File(filePath);
    await tempFile.writeAsBytes(document.bytes, flush: true);

    await Share.shareXFiles(<XFile>[
      XFile(tempFile.path, name: safeName, mimeType: document.format.mimeType),
    ], subject: document.fileName);
  } catch (e, stackTrace) {
    AppLogger.error(
      'ExportFileDispatcher',
      'Failed to share export file on native platform.',
      e,
      stackTrace,
    );
    throw StorageException(
      message: 'Failed to open native share sheet for exported file.',
      cause: e,
    );
  }
}

Future<void> _cleanupStaleExportTempFiles(Directory tempDir) async {
  try {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final entity in tempDir.list(followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('scannify_export_')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    }
  } catch (_) {
    // Non-critical cleanup best effort
  }
}
