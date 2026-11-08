import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';

/// Represents an acquired receipt image from the camera or photo gallery.
class AcquiredReceiptImage {
  const AcquiredReceiptImage({
    required this.path,
    required this.bytes,
    required this.mimeType,
  });

  final String path;
  final Uint8List bytes;
  final String? mimeType;
}

/// Abstract contract for capturing or importing and cropping a receipt image.
abstract interface class ImageAcquisitionService {
  /// Captures a new receipt photo from the device camera, or returns `null` if cancelled.
  Future<AcquiredReceiptImage?> captureFromCamera({bool enableCropping = true});

  /// Imports a receipt photo from the gallery, or returns `null` if cancelled.
  Future<AcquiredReceiptImage?> pickFromGallery({bool enableCropping = true});
}

/// Default implementation of [ImageAcquisitionService] using `image_picker` and `image_cropper`.
class DefaultImageAcquisitionService implements ImageAcquisitionService {
  DefaultImageAcquisitionService({
    ImagePicker? imagePicker,
    ImageCropper? imageCropper,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _imageCropper = imageCropper ?? ImageCropper();

  final ImagePicker _imagePicker;
  final ImageCropper _imageCropper;

  @override
  Future<AcquiredReceiptImage?> captureFromCamera({
    bool enableCropping = true,
  }) {
    return _acquire(source: ImageSource.camera, enableCropping: enableCropping);
  }

  @override
  Future<AcquiredReceiptImage?> pickFromGallery({bool enableCropping = true}) {
    return _acquire(
      source: ImageSource.gallery,
      enableCropping: enableCropping,
    );
  }

  Future<AcquiredReceiptImage?> _acquire({
    required ImageSource source,
    required bool enableCropping,
  }) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2400,
        maxHeight: 3200,
      );

      if (picked == null) {
        return null;
      }

      if (enableCropping && !kIsWeb && _isMobilePlatform) {
        final CroppedFile? cropped = await _cropMobileImage(picked.path);
        if (cropped != null) {
          final croppedBytes = await cropped.readAsBytes();
          return AcquiredReceiptImage(
            path: cropped.path,
            bytes: croppedBytes,
            mimeType: picked.mimeType,
          );
        }
      }

      final bytes = await picked.readAsBytes();
      return AcquiredReceiptImage(
        path: picked.path,
        bytes: bytes,
        mimeType: picked.mimeType,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'ImageAcquisitionService',
        'Failed to acquire receipt image.',
        e,
        stackTrace,
      );
      throw OcrException(
        message: 'Could not acquire receipt image from device.',
        cause: e,
      );
    }
  }

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<CroppedFile?> _cropMobileImage(String sourcePath) async {
    try {
      return await _imageCropper.cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: <PlatformUiSettings>[
          AndroidUiSettings(
            toolbarTitle: 'Adjust Receipt',
            toolbarColor: const Color(0xFF0B0D0C),
            toolbarWidgetColor: const Color(0xFFF5F7F5),
            activeControlsWidgetColor: const Color(0xFF10B981),
            backgroundColor: const Color(0xFF0B0D0C),
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Adjust Receipt', aspectRatioLockEnabled: false),
        ],
      );
    } catch (e) {
      // If cropping fails or is unsupported on the host, gracefully fall back to the picked image.
      AppLogger.warning(
        'ImageAcquisitionService',
        'Image cropper fallback to original image.',
        e,
      );
      return null;
    }
  }
}
