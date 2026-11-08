import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../../core/logging/app_logger.dart';

/// Temporary, OCR-optimized copy of a document photo. The caller owns the file
/// and MUST call [dispose] once OCR is finished (privacy: no leftover copies).
class PreparedOcrImage {
  PreparedOcrImage(this.path, {required this.skewDegrees});

  final String path;

  /// Skew angle (degrees) that was detected and corrected; `0` when none.
  final double skewDegrees;

  Future<void> dispose() async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort cleanup only.
    }
  }
}

/// Pure-Dart OCR preprocessing (runs in a background isolate).
///
/// Pipeline: EXIF orientation → scale to an OCR-friendly size → grayscale →
/// illumination flattening (shadow removal) → contrast stretch → deskew →
/// light sharpening.
///
/// Deliberately NOT included (needs a native CV library such as OpenCV, which
/// would add tens of MB to the APK): automatic document-edge detection and
/// perspective warping. Users can still crop manually via the image cropper.
class ImagePreprocessor {
  const ImagePreprocessor();

  /// Preprocesses the image at [sourcePath]. Returns `null` when the file cannot
  /// be decoded (unsupported/corrupted) so callers can fall back to the original.
  Future<PreparedOcrImage?> prepareFile(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final result = await compute(_processInIsolate, bytes);
      if (result == null) return null;
      final out = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'scannify_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(result.bytes, flush: true);
      return PreparedOcrImage(out.path, skewDegrees: result.skew);
    } catch (e) {
      AppLogger.warning('ImagePreprocessor', 'Preprocessing skipped.', e);
      return null;
    }
  }

  /// Synchronous variant used by tests and the isolate entry point.
  @visibleForTesting
  ({Uint8List bytes, double skew})? processBytes(Uint8List input) =>
      _process(input);

  /// Estimates the skew of text rows in degrees (positive = rows descend to the right).
  @visibleForTesting
  static double estimateSkewDegrees(img.Image gray) => _estimateSkew(gray);
}

({Uint8List bytes, double skew})? _processInIsolate(Uint8List input) =>
    _process(input);

({Uint8List bytes, double skew})? _process(Uint8List input) {
  img.Image? image;
  try {
    image = img.decodeImage(input);
  } catch (_) {
    return null;
  }
  if (image == null) return null;

  image = img.bakeOrientation(image);

  // Scale: upscale small captures (cap 2x) and bound very large ones.
  final longest = math.max(image.width, image.height);
  if (longest < 1400) {
    final factor = math.min(2.0, 2200 / longest);
    image = img.copyResize(
      image,
      width: (image.width * factor).round(),
      interpolation: img.Interpolation.cubic,
    );
  } else if (longest > 3000) {
    final factor = 3000 / longest;
    image = img.copyResize(
      image,
      width: (image.width * factor).round(),
      interpolation: img.Interpolation.average,
    );
  }

  image = img.grayscale(image);
  image = _flattenIllumination(image);
  image = img.normalize(image, min: 0, max: 255);

  final skew = _estimateSkew(image);
  if (skew.abs() >= 0.6) {
    image = img.copyRotate(
      image,
      angle: -skew,
      interpolation: img.Interpolation.linear,
    );
    image = _fillBorders(image);
  }

  image = img.convolution(
    image,
    filter: const <num>[0, -1, 0, -1, 5, -1, 0, -1, 0],
    div: 1,
    offset: 0,
  );

  return (
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    skew: skew.abs() >= 0.6 ? skew : 0.0,
  );
}

/// Divides by a heavily blurred copy so shadows and uneven lighting vanish.
img.Image _flattenIllumination(img.Image gray) {
  final w = gray.width;
  final h = gray.height;
  final small = img.copyResize(
    gray,
    width: math.max(32, w ~/ 8),
    interpolation: img.Interpolation.average,
  );
  final blurred = img.gaussianBlur(small, radius: 4);
  final bg = img.copyResize(
    blurred,
    width: w,
    height: h,
    interpolation: img.Interpolation.linear,
  );

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = gray.getPixel(x, y);
      final b = math.max(1, bg.getPixel(x, y).r.toInt());
      final v = (p.r.toInt() * 235 / b).clamp(0, 255).round();
      p
        ..r = v
        ..g = v
        ..b = v;
    }
  }
  return gray;
}

/// Replaces black corners created by rotation with white paper colour.
img.Image _fillBorders(img.Image image) {
  // Corner pixels outside the rotated page are pure black; text pixels are
  // rarely exactly 0 after normalization+flattening, so treat 0 on the border
  // rows/cols as background.
  final w = image.width;
  final h = image.height;
  void whiten(int x, int y) {
    final p = image.getPixel(x, y);
    if (p.r.toInt() == 0 && p.g.toInt() == 0 && p.b.toInt() == 0) {
      p
        ..r = 255
        ..g = 255
        ..b = 255;
    }
  }

  final band = math.max(4, (math.min(w, h) * 0.12).round());
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (x < band || y < band || x >= w - band || y >= h - band) whiten(x, y);
    }
  }
  return image;
}

/// Projection-profile skew estimator on a downscaled ink map.
double _estimateSkew(img.Image gray) {
  final scale = 600 / math.max(gray.width, gray.height);
  final small = scale < 1
      ? img.copyResize(
          gray,
          width: (gray.width * scale).round(),
          interpolation: img.Interpolation.average,
        )
      : gray;

  // Mean luminance → ink threshold.
  double sum = 0;
  for (final p in small) {
    sum += p.r;
  }
  final mean = sum / (small.width * small.height);
  final threshold = mean * 0.72;

  final xs = <int>[];
  final ys = <int>[];
  for (int y = 0; y < small.height; y++) {
    for (int x = 0; x < small.width; x++) {
      if (small.getPixel(x, y).r < threshold) {
        xs.add(x);
        ys.add(y);
      }
    }
  }
  if (xs.length < 50) return 0;

  final diag = math
      .sqrt(small.width * small.width + small.height * small.height)
      .ceil();
  double score(double degrees) {
    final rad = degrees * math.pi / 180;
    final c = math.cos(rad);
    final s = math.sin(rad);
    final hist = List<int>.filled(diag * 2 + 2, 0);
    for (int i = 0; i < xs.length; i++) {
      final yy = (ys[i] * c - xs[i] * s).round() + diag;
      hist[yy]++;
    }
    double acc = 0;
    for (final v in hist) {
      acc += v.toDouble() * v;
    }
    return acc;
  }

  final base = score(0);
  var bestAngle = 0.0;
  var bestScore = base;
  for (double a = -10; a <= 10; a += 1) {
    final sc = score(a);
    if (sc > bestScore) {
      bestScore = sc;
      bestAngle = a;
    }
  }
  for (double a = bestAngle - 1; a <= bestAngle + 1; a += 0.25) {
    final sc = score(a);
    if (sc > bestScore) {
      bestScore = sc;
      bestAngle = a;
    }
  }
  // Only trust a clear gain over the un-rotated projection.
  if (bestScore < base * 1.03) return 0;
  return bestAngle;
}
