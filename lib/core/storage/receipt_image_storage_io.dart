import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';
import '../logging/app_logger.dart';
import 'receipt_image_storage_service.dart';

ReceiptImageStorageService createPlatformImageStorageService() =>
    LocalFileReceiptImageStorageService();

/// Native file-system implementation of [ReceiptImageStorageService] for Android & iOS.
///
/// Stores receipt images in a dedicated application-private directory
/// (`<app_documents>/scannify_receipt_images/`) outside of the Hive database.
class LocalFileReceiptImageStorageService
    implements ReceiptImageStorageService {
  LocalFileReceiptImageStorageService({Directory? customBaseDirectory})
    : _customBaseDirectory = customBaseDirectory;

  static const String _subDirectoryName = 'scannify_receipt_images';

  final Directory? _customBaseDirectory;

  Future<Directory> _resolveImagesDirectory() async {
    final baseDir =
        _customBaseDirectory ?? await getApplicationDocumentsDirectory();
    final imagesDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}$_subDirectoryName',
    );
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  @override
  Future<String> saveReceiptImage({
    required String receiptId,
    String? sourcePath,
    Uint8List? bytes,
    String fileExtension = '.jpg',
  }) async {
    final sanitizedId = receiptId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitizedId.isEmpty) {
      throw const StorageException(
        message: 'Receipt ID cannot be empty when saving an image.',
      );
    }

    final normalizedExt = fileExtension.startsWith('.')
        ? fileExtension.toLowerCase()
        : '.${fileExtension.toLowerCase()}';

    try {
      Uint8List imageBytes;
      if (bytes != null) {
        imageBytes = bytes;
      } else if (sourcePath != null && sourcePath.trim().isNotEmpty) {
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          throw const StorageException(
            message: 'Source receipt image file does not exist.',
            code: 'IMAGE_NOT_FOUND',
          );
        }
        final fileLength = await sourceFile.length();
        if (fileLength > ReceiptImageStorageService.maxImageBytes) {
          throw const StorageException(
            message: 'Receipt image exceeds the 15 MB size limit.',
            code: 'IMAGE_TOO_LARGE',
          );
        }
        imageBytes = await sourceFile.readAsBytes();
      } else {
        throw const StorageException(
          message: 'Either sourcePath or bytes must be provided.',
        );
      }

      if (imageBytes.isEmpty) {
        throw const StorageException(
          message: 'Receipt image data cannot be empty.',
        );
      }
      if (imageBytes.lengthInBytes > ReceiptImageStorageService.maxImageBytes) {
        throw const StorageException(
          message: 'Receipt image exceeds the 15 MB size limit.',
          code: 'IMAGE_TOO_LARGE',
        );
      }

      final imagesDir = await _resolveImagesDirectory();
      final targetPath =
          '${imagesDir.path}${Platform.pathSeparator}receipt_${sanitizedId}_${DateTime.now().millisecondsSinceEpoch}$normalizedExt';
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(imageBytes, flush: true);

      return targetFile.path;
    } on StorageException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'ReceiptImageStorageService',
        'Failed to save receipt image to private storage.',
        e,
        stackTrace,
      );
      throw StorageException(
        message: 'Unable to save receipt image locally.',
        cause: e,
      );
    }
  }

  @override
  Future<Uint8List?> readReceiptImageBytes(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (e, stackTrace) {
      AppLogger.warning(
        'ReceiptImageStorageService',
        'Could not read receipt image file.',
        e,
      );
      AppLogger.error(
        'ReceiptImageStorageService',
        'Read error details.',
        e,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return false;
    }
    try {
      return await File(imagePath).exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteReceiptImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.warning(
        'ReceiptImageStorageService',
        'Failed to delete receipt image file.',
        e,
      );
    }
  }

  @override
  Future<void> deleteAllReceiptImages() async {
    try {
      final dir = await _resolveImagesDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'ReceiptImageStorageService',
        'Failed to delete all receipt images.',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<int> cleanupOrphanedImages(Set<String> activeImagePaths) async {
    int deletedCount = 0;
    try {
      final dir = await _resolveImagesDirectory();
      if (!await dir.exists()) return 0;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && !activeImagePaths.contains(entity.path)) {
          await entity.delete();
          deletedCount++;
        }
      }
    } catch (e) {
      AppLogger.warning(
        'ReceiptImageStorageService',
        'Failed during orphaned image cleanup.',
        e,
      );
    }
    return deletedCount;
  }
}
