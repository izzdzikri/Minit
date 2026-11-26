import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Binary waveform peaks persistence and downsampling helper.
///
/// Format: 1 byte (`uint8`, `0..255`) per 100 ms sample, mapping `0.0..1.0`
/// normalized mic amplitude. A 2-hour recording occupies only 72 KB on disk.
class PeaksStorage {
  PeaksStorage._();

  /// Noise floor in dBFS below which ambient room hum renders as a flat line.
  static const double noiseFloorDb = -42.0;
  static const double ceilingDb = -2.0;

  /// Normalizes a `record` dBFS measurement (`-160.0 .. 0.0`) into `0.0 .. 1.0`.
  /// Applies a quadratic perceptual curve above the noise floor so quiet ambient
  /// sounds stay low while soft and loud speech remain visibly distinct.
  static double normalizeAmplitudeDb(double db) {
    if (!db.isFinite || db <= noiseFloorDb) return 0.0;
    final linearDb =
        ((db - noiseFloorDb) / (ceilingDb - noiseFloorDb)).clamp(0.0, 1.0);
    return (linearDb * linearDb).clamp(0.0, 1.0);
  }

  static int encodePeakByte(double normalizedLevel) {
    return (normalizedLevel.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
  }

  static double decodePeakByte(int byteValue) {
    return (byteValue.clamp(0, 255)) / 255.0;
  }

  /// Concatenates segment `.peaks` files in order into a single `.peaks` file
  /// atomically via a `.tmp` file.
  static Future<String?> mergeSegmentPeaks({
    required List<String> segmentPeaksPaths,
    required String outputPeaksPath,
  }) async {
    final existing = segmentPeaksPaths
        .map(File.new)
        .where((f) => f.existsSync() && f.lengthSync() > 0)
        .toList();
    if (existing.isEmpty) return null;

    final outFile = File(outputPeaksPath);
    outFile.parent.createSync(recursive: true);
    final tmpFile = File('$outputPeaksPath.tmp');
    if (tmpFile.existsSync()) {
      tmpFile.deleteSync();
    }

    final raf = tmpFile.openSync(mode: FileMode.writeOnly);
    try {
      for (final seg in existing) {
        raf.writeFromSync(seg.readAsBytesSync());
      }
      raf.flushSync();
    } finally {
      raf.closeSync();
    }

    if (outFile.existsSync()) {
      outFile.deleteSync();
    }
    tmpFile.renameSync(outFile.path);
    return outFile.path;
  }

  /// Writes raw normalized `0.0..1.0` levels into a `.peaks` file.
  static Future<String> writeNormalizedPeaks({
    required List<double> levels,
    required String outputPeaksPath,
  }) async {
    final bytes = Uint8List(levels.length);
    for (var i = 0; i < levels.length; i++) {
      bytes[i] = encodePeakByte(levels[i]);
    }
    final file = File(outputPeaksPath);
    file.parent.createSync(recursive: true);
    final tmp = File('$outputPeaksPath.tmp');
    tmp.writeAsBytesSync(bytes, flush: true);
    if (file.existsSync()) file.deleteSync();
    tmp.renameSync(file.path);
    return file.path;
  }

  /// Reads raw `uint8` peak bytes from disk, returning `null` if missing or empty.
  static Future<Uint8List?> readPeaksFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  /// Synchronous read helper for small `.peaks` files (`<= ~100 KB`).
  static Uint8List? readPeaksFileSync(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    return bytes.isEmpty ? null : bytes;
  }

  /// Downsamples raw 100 ms peak bytes to [targetBarCount] normalized `0.0..1.0`
  /// bars using peak-preserving bucket maxima so speech transients remain visible
  /// even for 2-hour (`72,000` sample) recordings.
  static List<double> downsamplePeaks(Uint8List? peaks, int targetBarCount) {
    if (peaks == null || peaks.isEmpty || targetBarCount <= 0) {
      return const [];
    }

    if (peaks.length <= targetBarCount) {
      return List<double>.generate(
        peaks.length,
        (i) => decodePeakByte(peaks[i]),
        growable: false,
      );
    }

    final result = List<double>.filled(targetBarCount, 0.0, growable: false);
    final step = peaks.length / targetBarCount;
    for (var i = 0; i < targetBarCount; i++) {
      final start = (i * step).floor().clamp(0, peaks.length - 1);
      final rawEnd = ((i + 1) * step).ceil();
      final end = math.max(start + 1, rawEnd).clamp(1, peaks.length);

      var bucketMax = 0;
      for (var j = start; j < end; j++) {
        if (peaks[j] > bucketMax) {
          bucketMax = peaks[j];
        }
      }
      result[i] = decodePeakByte(bucketMax);
    }
    return result;
  }
}
