import 'dart:typed_data';

import 'receipt_image_storage_stub.dart'
    if (dart.library.io) 'receipt_image_storage_io.dart'
    if (dart.library.js_interop) 'receipt_image_storage_web.dart';

/// Abstract contract for storing, retrieving, and cleaning up receipt images
/// outside of the main receipt database.
///
/// - On Android & iOS: stores image files in an application-private directory
///   and returns the local file path as `imagePath`.
/// - On Web: stores compressed image bytes in a dedicated separate IndexedDB
///   blob store and returns a `web_img://<id>` reference key so raw bytes never
///   bloat the `Receipt` database box.
abstract interface class ReceiptImageStorageService {
  /// Maximum allowed image size in bytes (15 MB) to guard against storage exhaustion.
  static const int maxImageBytes = 15 * 1024 * 1024;

  /// Factory returning the platform-appropriate [ReceiptImageStorageService].
  factory ReceiptImageStorageService() => createPlatformImageStorageService();

  /// Persists a receipt image from [sourcePath] (or [bytes] when on Web)
  /// into application-private storage and returns the persistent `imagePath` reference.
  Future<String> saveReceiptImage({
    required String receiptId,
    String? sourcePath,
    Uint8List? bytes,
    String fileExtension = '.jpg',
  });

  /// Reads the raw bytes of a stored receipt image identified by [imagePath].
  ///
  /// Returns `null` gracefully if [imagePath] is null, empty, or the underlying
  /// file no longer exists.
  Future<Uint8List?> readReceiptImageBytes(String? imagePath);

  /// Checks whether the receipt image referenced by [imagePath] exists and is accessible.
  Future<bool> imageExists(String? imagePath);

  /// Deletes the stored image referenced by [imagePath].
  ///
  /// Safely no-ops if [imagePath] is null or the file is already missing.
  Future<void> deleteReceiptImage(String? imagePath);

  /// Deletes all stored receipt images and cleans up any orphaned files.
  Future<void> deleteAllReceiptImages();

  /// Removes orphaned image files that are not referenced by any path in [activeImagePaths].
  Future<int> cleanupOrphanedImages(Set<String> activeImagePaths);
}
