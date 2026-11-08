import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:hive_ce/hive_ce.dart';

import '../errors/app_exception.dart';
import '../logging/app_logger.dart';
import 'receipt_image_storage_service.dart';

ReceiptImageStorageService createPlatformImageStorageService() =>
    WebIndexedDbReceiptImageStorageService();

/// Web implementation of [ReceiptImageStorageService].
///
/// Stores receipt image binary blobs in a dedicated separate IndexedDB store
/// (`scannify_web_image_blobs_box`) outside of the `Receipt` entity database,
/// returning a lightweight `web_img://<key>` reference in `Receipt.imagePath`.
class WebIndexedDbReceiptImageStorageService
    implements ReceiptImageStorageService {
  static const String _blobBoxName = 'scannify_web_image_blobs_box';
  static const String _schemePrefix = 'web_img://';

  Future<Box<List<int>>> _openBlobBox() async {
    if (Hive.isBoxOpen(_blobBoxName)) {
      return Hive.box<List<int>>(_blobBoxName);
    }
    return Hive.openBox<List<int>>(_blobBoxName);
  }

  String _extractBoxKey(String imagePath) {
    if (imagePath.startsWith(_schemePrefix)) {
      return imagePath.substring(_schemePrefix.length);
    }
    return imagePath;
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

    try {
      Uint8List resolvedBytes;
      if (bytes != null) {
        resolvedBytes = bytes;
      } else if (sourcePath != null && sourcePath.trim().isNotEmpty) {
        resolvedBytes = await XFile(sourcePath).readAsBytes();
      } else {
        throw const StorageException(
          message: 'Either sourcePath or bytes must be provided on Web.',
        );
      }

      if (resolvedBytes.isEmpty) {
        throw const StorageException(
          message: 'Receipt image data cannot be empty.',
        );
      }
      if (resolvedBytes.lengthInBytes >
          ReceiptImageStorageService.maxImageBytes) {
        throw const StorageException(
          message: 'Receipt image exceeds the 15 MB size limit.',
          code: 'IMAGE_TOO_LARGE',
        );
      }

      final box = await _openBlobBox();
      final key =
          'receipt_${sanitizedId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      await box.put(key, resolvedBytes);
      return '$_schemePrefix$key';
    } on StorageException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'WebReceiptImageStorageService',
        'Failed to store receipt image in browser IndexedDB.',
        e,
        stackTrace,
      );
      throw StorageException(
        message: 'Unable to store receipt image in browser storage.',
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
      final box = await _openBlobBox();
      final rawList = box.get(_extractBoxKey(imagePath));
      if (rawList == null) return null;
      return Uint8List.fromList(rawList);
    } catch (e) {
      AppLogger.warning(
        'WebReceiptImageStorageService',
        'Failed to read receipt image from browser IndexedDB.',
        e,
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
      final box = await _openBlobBox();
      return box.containsKey(_extractBoxKey(imagePath));
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
      final box = await _openBlobBox();
      await box.delete(_extractBoxKey(imagePath));
    } catch (e) {
      AppLogger.warning(
        'WebReceiptImageStorageService',
        'Failed to delete receipt image from browser IndexedDB.',
        e,
      );
    }
  }

  @override
  Future<void> deleteAllReceiptImages() async {
    try {
      final box = await _openBlobBox();
      await box.clear();
    } catch (e) {
      AppLogger.warning(
        'WebReceiptImageStorageService',
        'Failed to clear browser image storage.',
        e,
      );
    }
  }

  @override
  Future<int> cleanupOrphanedImages(Set<String> activeImagePaths) async {
    int deletedCount = 0;
    try {
      final box = await _openBlobBox();
      final activeKeys = activeImagePaths.map(_extractBoxKey).toSet();
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        if (!activeKeys.contains(key.toString())) {
          keysToDelete.add(key);
        }
      }
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        deletedCount = keysToDelete.length;
      }
    } catch (e) {
      AppLogger.warning(
        'WebReceiptImageStorageService',
        'Failed during orphaned Web image cleanup.',
        e,
      );
    }
    return deletedCount;
  }
}
