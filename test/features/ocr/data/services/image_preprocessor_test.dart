import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scannify/features/ocr/data/services/image_preprocessor.dart';

/// Draws rows of "words" (black blocks) tilted so rows descend to the right by [deg].
img.Image _tiltedPage(double deg, {bool shadow = false}) {
  const w = 700;
  const h = 500;
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(235, 235, 235));
  final slope = math.tan(deg * math.pi / 180);
  for (int row = 0; row < 12; row++) {
    final y0 = 60 + row * 30;
    for (int wordStart = 40; wordStart < 640; wordStart += 55) {
      for (int x = wordStart; x < wordStart + 40; x++) {
        final y = (y0 + (x - 40) * slope).round();
        for (int t = 0; t < 8; t++) {
          if (y + t >= 0 && y + t < h) image.setPixelRgb(x, y + t, 20, 20, 20);
        }
      }
    }
  }
  if (shadow) {
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final f =
            0.45 + 0.55 * (x / w); // dark on the left, bright on the right
        p
          ..r = (p.r * f).round()
          ..g = (p.g * f).round()
          ..b = (p.b * f).round();
      }
    }
  }
  return image;
}

void main() {
  test('skew estimator detects the tilt direction and magnitude', () {
    final tilted = img.grayscale(_tiltedPage(4));
    final skew = ImagePreprocessor.estimateSkewDegrees(tilted);
    expect(skew, closeTo(4, 1.2));

    final straight = img.grayscale(_tiltedPage(0));
    expect(
      ImagePreprocessor.estimateSkewDegrees(straight).abs(),
      lessThan(0.6),
    );
  });

  test('processBytes deskews a tilted page (residual skew is small)', () {
    final bytes = img.encodePng(_tiltedPage(5));
    final out = const ImagePreprocessor().processBytes(bytes);
    expect(out, isNotNull);
    expect(out!.skew, closeTo(5, 1.5));

    final decoded = img.decodeImage(out.bytes)!;
    final residual = ImagePreprocessor.estimateSkewDegrees(
      img.grayscale(decoded),
    );
    expect(residual.abs(), lessThan(1.5));
  });

  test('illumination flattening reduces the left/right brightness gap', () {
    final shaded = _tiltedPage(0, shadow: true);
    double meanCols(img.Image im, int x0, int x1) {
      double s = 0;
      int n = 0;
      for (int y = 0; y < im.height; y++) {
        for (int x = x0; x < x1; x++) {
          s += im.getPixel(x, y).r;
          n++;
        }
      }
      return s / n;
    }

    final gapBefore =
        (meanCols(shaded, 0, 60) -
                meanCols(shaded, shaded.width - 60, shaded.width))
            .abs();

    final out = const ImagePreprocessor().processBytes(img.encodePng(shaded))!;
    final after = img.decodeImage(out.bytes)!;
    final gapAfter =
        (meanCols(after, 0, 120) -
                meanCols(after, after.width - 120, after.width))
            .abs();

    expect(gapAfter, lessThan(gapBefore * 0.5));
  });

  test('returns null for undecodable bytes instead of throwing', () {
    final out = const ImagePreprocessor().processBytes(
      img.encodePng(img.Image(width: 1, height: 1)).sublist(0, 5),
    );
    expect(out, isNull);
  });
}
