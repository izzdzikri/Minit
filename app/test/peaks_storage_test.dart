import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:minit/models/recording_item.dart';
import 'package:minit/services/native_bridge.dart';
import 'package:minit/services/peaks_storage.dart';
import 'package:minit/services/recording_storage.dart';
import 'package:minit/theme/minute_theme.dart';
import 'package:minit/widgets/waveform_view.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PeaksStorage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minute_peaks_test_');
      RecordingStorage.testBaseDirectory = tempDir;
    });

    tearDown(() async {
      RecordingStorage.testBaseDirectory = null;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('normalizes dBFS with -42 dB noise floor and quadratic speech curve',
        () {
      expect(PeaksStorage.normalizeAmplitudeDb(-160.0), 0.0);
      expect(PeaksStorage.normalizeAmplitudeDb(-42.0), 0.0);
      expect(PeaksStorage.normalizeAmplitudeDb(-2.0), 1.0);
      expect(PeaksStorage.normalizeAmplitudeDb(0.0), 1.0);

      final ambient = PeaksStorage.normalizeAmplitudeDb(-32.0); // 0.25^2
      final quietSpeech = PeaksStorage.normalizeAmplitudeDb(-22.0); // 0.50^2
      final loudSpeech = PeaksStorage.normalizeAmplitudeDb(-6.0); // 0.90^2

      expect(ambient, closeTo(0.0625, 0.005));
      expect(quietSpeech, closeTo(0.25, 0.005));
      expect(loudSpeech, closeTo(0.81, 0.005));
      expect(loudSpeech - ambient, greaterThan(0.7));
    });

    test('writes, reads, and merges ordered segment .peaks files', () async {
      final seg1 = p.join(tempDir.path, 'seg_0001.peaks');
      final seg2 = p.join(tempDir.path, 'seg_0002.peaks');
      final mergedPath = p.join(tempDir.path, 'full.peaks');

      await PeaksStorage.writeNormalizedPeaks(
        levels: const [0.0, 0.25, 0.5],
        outputPeaksPath: seg1,
      );
      await PeaksStorage.writeNormalizedPeaks(
        levels: const [0.75, 1.0],
        outputPeaksPath: seg2,
      );

      final out = await PeaksStorage.mergeSegmentPeaks(
        segmentPeaksPaths: [seg1, seg2],
        outputPeaksPath: mergedPath,
      );
      expect(out, mergedPath);

      final loaded = await PeaksStorage.readPeaksFile(mergedPath);
      expect(loaded, isNotNull);
      expect(loaded!.length, 5);
      expect(loaded[0], 0);
      expect(loaded[4], 255);
      expect(await PeaksStorage.readPeaksFile(p.join(tempDir.path, 'nope.peaks')), isNull);
    });

    test('downsamples 2-hour 72,000-sample waveform while preserving spikes', () {
      final twoHours = Uint8List(72000);
      twoHours[36000] = 250;
      twoHours[71999] = 200;

      final bars = PeaksStorage.downsamplePeaks(twoHours, 120);
      expect(bars.length, 120);
      expect(bars[60], closeTo(250 / 255.0, 0.01));
      expect(bars[119], closeTo(200 / 255.0, 0.01));
      expect(bars[0], 0.0);
    });

    test('crash recovery rebuilds merged .peaks alongside recovered .m4a', () async {
      final pendingRoot = await RecordingStorage.getPendingRootDirectory();
      final pendingDir = Directory(p.join(pendingRoot.path, 'rec_crash_1'))
        ..createSync(recursive: true);

      File(p.join(pendingDir.path, 'seg_0001.aac'))
          .writeAsBytesSync(List<int>.filled(64, 1));
      File(p.join(pendingDir.path, 'seg_0002.aac'))
          .writeAsBytesSync(List<int>.filled(64, 2));

      await PeaksStorage.writeNormalizedPeaks(
        levels: const [0.2, 0.4, 0.6],
        outputPeaksPath: p.join(pendingDir.path, 'seg_0001.peaks'),
      );
      await PeaksStorage.writeNormalizedPeaks(
        levels: const [0.8, 1.0],
        outputPeaksPath: p.join(pendingDir.path, 'seg_0002.peaks'),
      );

      final meta = PendingSessionMetadata(
        sessionId: 'rec_crash_1',
        title: 'Interrupted Lecture',
        createdAt: DateTime.utc(2026, 11, 26, 6, 0, 0),
        segmentFiles: const ['seg_0001.aac', 'seg_0002.aac'],
        peaksFiles: const ['seg_0001.peaks', 'seg_0002.peaks'],
        elapsedMs: 500,
        language: 'mixed',
        isForceMode: true,
        markers: const [
          TimelineMarker(
            type: MarkerType.marker,
            startMs: 300,
            reason: 'Exam hint',
          ),
        ],
      );
      File(p.join(pendingDir.path, 'session.json'))
          .writeAsStringSync(String.fromCharCodes(meta.toJsonStringCompat()));

      final recovered = await RecordingStorage.recoverPendingSessions(
        mergeAudioOverride: ({
          required List<String> segmentPaths,
          required String outputPath,
        }) async {
          File(outputPath).writeAsBytesSync([1, 2, 3, 4]);
          return MergeResult(
            outputPath: outputPath,
            sizeBytes: 4,
            durationMs: 500,
            segmentsMerged: segmentPaths.length,
            sampleRate: 16000,
            channelCount: 1,
          );
        },
      );

      expect(recovered.length, 1);
      final item = recovered.first;
      expect(item.isPartial, isTrue);
      expect(item.isForceMode, isTrue);
      expect(item.language, 'mixed');
      expect(item.markers.length, 1);
      expect(item.peaksPath, isNotNull);

      final peaks = await PeaksStorage.readPeaksFile(item.peaksPath);
      expect(peaks, isNotNull);
      expect(peaks!.length, 5);
    });
  });

  testWidgets('ReplayWaveformView renders slider fallback when .peaks missing',
      (tester) async {
    Duration? sought;
    await tester.pumpWidget(
      MaterialApp(
        theme: MinuteTheme.light(),
        home: Scaffold(
          body: ReplayWaveformView(
            peaks: null,
            position: const Duration(seconds: 30),
            duration: const Duration(minutes: 2),
            markers: const [
              TimelineMarker(
                type: MarkerType.marker,
                startMs: 45000,
                reason: 'Check slide',
              ),
            ],
            onSeek: (d) => sought = d,
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('00:30'), findsOneWidget);
    expect(find.textContaining('02:00'), findsOneWidget);

    await tester.tap(find.text('Marker 00:45'));
    await tester.pump();
    expect(sought, const Duration(seconds: 45));
  });
}

extension on PendingSessionMetadata {
  List<int> toJsonStringCompat() {
    final map = toJson();
    final encoded = StringBuffer('{');
    var first = true;
    map.forEach((k, v) {
      if (!first) encoded.write(',');
      first = false;
      encoded.write('"');
      encoded.write(k);
      encoded.write('":');
      encoded.write(_encodeJsonValue(v));
    });
    encoded.write('}');
    return encoded.toString().codeUnits;
  }
}

String _encodeJsonValue(Object? v) {
  if (v == null) return 'null';
  if (v is num || v is bool) return v.toString();
  if (v is String) {
    final escaped = v
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    return '"$escaped"';
  }
  if (v is List) {
    return '[${v.map(_encodeJsonValue).join(',')}]';
  }
  if (v is Map) {
    final parts = v.entries
        .map((e) => '"${e.key}":${_encodeJsonValue(e.value)}')
        .join(',');
    return '{$parts}';
  }
  return '"$v"';
}
