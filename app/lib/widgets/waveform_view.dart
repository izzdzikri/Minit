import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../models/recording_item.dart';
import '../services/peaks_storage.dart';
import '../theme/minute_tokens.dart';

/// Holds rolling 30-second live microphone level samples (100 ms per slot)
/// in a fixed-size ring buffer so [LiveWaveformView] repaints with zero
/// per-frame list allocations.
class LiveWaveformController extends ChangeNotifier {
  LiveWaveformController({this.capacity = 300})
      : _buffer = Float64List(capacity);

  final int capacity;
  final Float64List _buffer;
  final List<TimelineMarker> _markers = <TimelineMarker>[];

  int _head = 0;
  int _count = 0;
  bool _isPaused = false;
  int _latestElapsedMs = 0;

  int get length => _count;

  double sampleAt(int index) {
    assert(index >= 0 && index < _count);
    final slot = (_head + index) % capacity;
    return _buffer[slot];
  }

  List<double> get levels => List<double>.generate(
        _count,
        sampleAt,
        growable: false,
      );

  List<TimelineMarker> get markers => List<TimelineMarker>.unmodifiable(_markers);
  bool get isPaused => _isPaused;
  int get latestElapsedMs => _latestElapsedMs;
  double get currentLevel => _count == 0 ? 0.0 : sampleAt(_count - 1);

  void _pushNormalized(double level) {
    final clamped = level.clamp(0.0, 1.0).toDouble();
    if (_count < capacity) {
      final writeIndex = (_head + _count) % capacity;
      _buffer[writeIndex] = clamped;
      _count++;
    } else {
      _buffer[_head] = clamped;
      _head = (_head + 1) % capacity;
    }
  }

  void addSample(double level, {required int elapsedMs}) {
    _pushNormalized(level);
    _latestElapsedMs = elapsedMs;
    notifyListeners();
  }

  void addSamples(List<double> samples, {required int elapsedMs}) {
    if (samples.isEmpty) {
      if (_latestElapsedMs != elapsedMs) {
        _latestElapsedMs = elapsedMs;
        notifyListeners();
      }
      return;
    }
    final start = samples.length > capacity ? samples.length - capacity : 0;
    for (var i = start; i < samples.length; i++) {
      _pushNormalized(samples[i]);
    }
    _latestElapsedMs = elapsedMs;
    notifyListeners();
  }

  void setHistory(
    List<double> levels, {
    required int elapsedMs,
    required bool paused,
    List<TimelineMarker> markers = const [],
  }) {
    _head = 0;
    _count = 0;
    final start = levels.length > capacity ? levels.length - capacity : 0;
    for (var i = start; i < levels.length; i++) {
      _pushNormalized(levels[i]);
    }
    _latestElapsedMs = elapsedMs;
    _isPaused = paused;
    _markers
      ..clear()
      ..addAll(markers);
    notifyListeners();
  }

  void updateState({
    required bool paused,
    required int elapsedMs,
    List<TimelineMarker>? markers,
  }) {
    final markersChanged = markers != null && !_markersMatch(markers);
    if (_isPaused == paused && !markersChanged && _isPaused) {
      return;
    }
    _isPaused = paused;
    _latestElapsedMs = elapsedMs;
    if (markers != null && markersChanged) {
      _markers
        ..clear()
        ..addAll(markers);
    }
    notifyListeners();
  }

  bool _markersMatch(List<TimelineMarker> other) {
    if (_markers.length != other.length) return false;
    for (var i = 0; i < _markers.length; i++) {
      if (_markers[i].startMs != other[i].startMs ||
          _markers[i].endMs != other[i].endMs ||
          _markers[i].type != other[i].type ||
          _markers[i].reason != other[i].reason) {
        return false;
      }
    }
    return true;
  }

  void reset() {
    _head = 0;
    _count = 0;
    _markers.clear();
    _isPaused = false;
    _latestElapsedMs = 0;
    notifyListeners();
  }
}

/// Scrolling live waveform (~30s window, newest on the right).
/// Repaints only itself via [CustomPainter] and falls back to a static level
/// meter when the system "remove animations" setting is enabled.
class LiveWaveformView extends StatelessWidget {
  const LiveWaveformView({
    super.key,
    required this.controller,
    this.height = 88,
  });

  final LiveWaveformController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          border: Border.all(color: c.border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MinuteSpacing.sm,
          vertical: MinuteSpacing.sm,
        ),
        child: disableAnimations
            ? ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final level =
                      controller.isPaused ? 0.0 : controller.currentLevel;
                  final activeColor =
                      controller.isPaused ? c.textMuted : c.accent;
                  return Semantics(
                    label: controller.isPaused
                        ? 'Microphone paused'
                        : 'Live microphone level ${(level * 100).round()} percent',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(MinuteRadii.pill),
                          child: LinearProgressIndicator(
                            value: level,
                            minHeight: 12,
                            backgroundColor: c.border,
                            color: activeColor,
                          ),
                        ),
                        const SizedBox(height: MinuteSpacing.xs),
                        Text(
                          controller.isPaused
                              ? 'Paused'
                              : 'Input level: ${(level * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              )
            : Semantics(
                label: 'Live audio waveform',
                child: SizedBox.expand(
                  child: CustomPaint(
                    isComplex: false,
                    willChange: true,
                    painter: _LiveWaveformPainter(
                      controller: controller,
                      activeColor: c.accent,
                      pausedColor: c.textMuted,
                      markerColor: c.warning,
                      baselineColor: c.border,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({
    required this.controller,
    required this.activeColor,
    required this.pausedColor,
    required this.markerColor,
    required this.baselineColor,
  })  : _baselinePaint = Paint()
          ..color = baselineColor
          ..strokeWidth = 1,
        _barPaint = Paint()
          ..strokeWidth = _barWidth
          ..strokeCap = StrokeCap.round,
        _tickPaint = Paint()
          ..color = markerColor
          ..strokeWidth = 2.0,
        super(repaint: controller);

  static const double _barWidth = 3.0;
  static const double _barGap = 2.5;
  static const double _step = _barWidth + _barGap;

  final LiveWaveformController controller;
  final Color activeColor;
  final Color pausedColor;
  final Color markerColor;
  final Color baselineColor;

  final Paint _baselinePaint;
  final Paint _barPaint;
  final Paint _tickPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      _baselinePaint,
    );

    final totalCount = controller.length;
    if (totalCount == 0) return;

    final visibleSlots =
        math.min(controller.capacity, math.max(1, (size.width / _step).floor()));
    _barPaint.color = controller.isPaused ? pausedColor : activeColor;

    final startIndex =
        totalCount > visibleSlots ? totalCount - visibleSlots : 0;
    final visibleCount = totalCount - startIndex;
    final minHalf = 1.5;
    final maxHalf = (size.height / 2) - 4;

    // Anchor newest sample on the right edge with zero list allocations.
    for (var i = 0; i < visibleCount; i++) {
      final level = controller.sampleAt(startIndex + i);
      final x = size.width - (visibleCount - 1 - i) * _step - (_barWidth / 2);
      if (x < 0) continue;

      final halfHeight = minHalf + (level * (maxHalf - minHalf));
      canvas.drawLine(
        Offset(x, centerY - halfHeight),
        Offset(x, centerY + halfHeight),
        _barPaint,
      );
    }

    // Draw markers and gap ticks within the visible 30s window.
    final windowMs = visibleSlots * 100;
    final latestMs = controller.latestElapsedMs;
    final minWindowMs = latestMs - windowMs;

    for (final marker in controller._markers) {
      if (marker.startMs < minWindowMs || marker.startMs > latestMs) continue;
      final slotsFromRight = (latestMs - marker.startMs) / 100.0;
      final x = size.width - slotsFromRight * _step - (_barWidth / 2);
      if (x < 0 || x > size.width) continue;

      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), _tickPaint);
      canvas.drawCircle(Offset(x, 4), 3, _tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.pausedColor != pausedColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.baselineColor != baselineColor;
  }
}

/// Compact static waveform thumbnail used on [MeetingCard] in the Library.
class MiniWaveformThumbnail extends StatelessWidget {
  const MiniWaveformThumbnail({
    super.key,
    required this.peaks,
    this.width = 48,
    this.height = 24,
  });

  final Uint8List? peaks;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final bars = PeaksStorage.downsamplePeaks(peaks, 16);
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _MiniWaveformPainter(
            bars: bars,
            color: bars.isEmpty ? c.border : c.accentText,
          ),
        ),
      ),
    );
  }
}

class _MiniWaveformPainter extends CustomPainter {
  _MiniWaveformPainter({required this.bars, required this.color})
      : _paint = Paint()
          ..color = color
          ..strokeWidth = bars.isEmpty ? 1.5 : 2.0
          ..strokeCap = StrokeCap.round;

  final List<double> bars;
  final Color color;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    if (bars.isEmpty) {
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        _paint,
      );
      return;
    }

    final step = size.width / bars.length;
    for (var i = 0; i < bars.length; i++) {
      final x = i * step + step / 2;
      final half = 1.5 + bars[i] * ((size.height / 2) - 2);
      canvas.drawLine(
        Offset(x, centerY - half),
        Offset(x, centerY + half),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter oldDelegate) {
    return oldDelegate.color != color || !listEquals(oldDelegate.bars, bars);
  }
}

/// Full-length interactive replay waveform for Meeting Detail.
/// Supports tap/drag scrubbing with finger time tooltip, clickable marker/call/
/// silence ticks, TalkBack slider semantics, and a progress-bar fallback when
/// older recordings lack a `.peaks` file.
class ReplayWaveformView extends StatefulWidget {
  const ReplayWaveformView({
    super.key,
    required this.peaks,
    required this.position,
    required this.duration,
    required this.markers,
    required this.onSeek,
  });

  final Uint8List? peaks;
  final Duration position;
  final Duration duration;
  final List<TimelineMarker> markers;
  final ValueChanged<Duration> onSeek;

  @override
  State<ReplayWaveformView> createState() => _ReplayWaveformViewState();
}

class _ReplayWaveformViewState extends State<ReplayWaveformView> {
  Uint8List? _cachedSource;
  int _cachedBarCount = 0;
  List<double> _cachedBars = const [];

  bool _isDragging = false;
  double _dragFraction = 0.0;

  List<double> _getDownsampledBars(int barCount) {
    if (widget.peaks == null || widget.peaks!.isEmpty || barCount <= 0) {
      return const [];
    }
    if (identical(_cachedSource, widget.peaks) &&
        _cachedBarCount == barCount &&
        _cachedBars.isNotEmpty) {
      return _cachedBars;
    }
    _cachedSource = widget.peaks;
    _cachedBarCount = barCount;
    _cachedBars = PeaksStorage.downsamplePeaks(widget.peaks, barCount);
    return _cachedBars;
  }

  double get _effectiveFraction {
    if (_isDragging) return _dragFraction.clamp(0.0, 1.0);
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  Duration _fractionToDuration(double fraction) {
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return Duration.zero;
    return Duration(milliseconds: (fraction.clamp(0.0, 1.0) * totalMs).round());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final theme = Theme.of(context);
    final totalMs = widget.duration.inMilliseconds;
    final hasPeaks = widget.peaks != null && widget.peaks!.isNotEmpty;

    final currentPos =
        _isDragging ? _fractionToDuration(_dragFraction) : widget.position;
    final stepMs = math.max(1000, (totalMs * 0.05).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          slider: true,
          label: 'Audio playback position',
          value:
              '${TimelineMarker.formatTimestamp(currentPos.inMilliseconds)} of ${TimelineMarker.formatTimestamp(totalMs)}',
          increasedValue: TimelineMarker.formatTimestamp(
            (currentPos.inMilliseconds + stepMs).clamp(0, totalMs),
          ),
          decreasedValue: TimelineMarker.formatTimestamp(
            (currentPos.inMilliseconds - stepMs).clamp(0, totalMs),
          ),
          onIncrease: totalMs <= 0
              ? null
              : () => widget.onSeek(
                    Duration(
                      milliseconds: (widget.position.inMilliseconds + stepMs)
                          .clamp(0, totalMs),
                    ),
                  ),
          onDecrease: totalMs <= 0
              ? null
              : () => widget.onSeek(
                    Duration(
                      milliseconds: (widget.position.inMilliseconds - stepMs)
                          .clamp(0, totalMs),
                    ),
                  ),
          child: hasPeaks
              ? _buildWaveformSurface(context, c, theme)
              : _buildFallbackSlider(context, c, totalMs),
        ),
        const SizedBox(height: MinuteSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              TimelineMarker.formatTimestamp(currentPos.inMilliseconds),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              TimelineMarker.formatTimestamp(totalMs),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (widget.markers.isNotEmpty) ...[
          const SizedBox(height: MinuteSpacing.sm),
          Wrap(
            spacing: MinuteSpacing.sm,
            runSpacing: MinuteSpacing.xs,
            children: [
              for (final marker in widget.markers)
                _MarkerJumpChip(
                  marker: marker,
                  onTap: () => widget.onSeek(
                    Duration(milliseconds: marker.startMs),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackSlider(
    BuildContext context,
    MinuteColors c,
    int totalMs,
  ) {
    final safeMax = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final posMs = widget.position.inMilliseconds.clamp(0, totalMs).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MinuteSpacing.sm,
        vertical: MinuteSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(MinuteRadii.card),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Slider(
        value: posMs,
        max: safeMax,
        activeColor: c.accent,
        inactiveColor: c.border,
        onChanged: totalMs <= 0
            ? null
            : (v) => widget.onSeek(Duration(milliseconds: v.round())),
      ),
    );
  }

  Widget _buildWaveformSurface(
    BuildContext context,
    MinuteColors c,
    ThemeData theme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barCount = math.max(24, (width / 4.2).floor().clamp(24, 160));
        final bars = _getDownsampledBars(barCount);
        final fraction = _effectiveFraction;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (width <= 0) return;
            final f = (details.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onSeek(_fractionToDuration(f));
          },
          onHorizontalDragStart: (details) {
            if (width <= 0) return;
            setState(() {
              _isDragging = true;
              _dragFraction =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragUpdate: (details) {
            if (width <= 0) return;
            setState(() {
              _dragFraction =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (_) {
            final target = _fractionToDuration(_dragFraction);
            setState(() => _isDragging = false);
            widget.onSeek(target);
          },
          onHorizontalDragCancel: () {
            setState(() => _isDragging = false);
          },
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(MinuteRadii.card),
              border: Border.all(color: c.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MinuteSpacing.sm,
              vertical: MinuteSpacing.sm,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RepaintBoundary(
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: _ReplayWaveformPainter(
                        bars: bars,
                        progress: fraction,
                        durationMs: widget.duration.inMilliseconds,
                        markers: widget.markers,
                        playedColor: c.accent,
                        unplayedColor: c.textMuted.withAlpha(90),
                        playheadColor: c.textPrimary,
                        markerColor: c.warning,
                        silenceOverlayColor: c.warningSubtle.withAlpha(140),
                      ),
                    ),
                  ),
                ),
                if (_isDragging)
                  Positioned(
                    left: (fraction * (width - 64)).clamp(0.0, math.max(0.0, width - 64)),
                    top: -28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.textPrimary,
                        borderRadius: BorderRadius.circular(MinuteRadii.sm),
                      ),
                      child: Text(
                        TimelineMarker.formatTimestamp(
                          _fractionToDuration(fraction).inMilliseconds,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: c.background,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReplayWaveformPainter extends CustomPainter {
  _ReplayWaveformPainter({
    required this.bars,
    required this.progress,
    required this.durationMs,
    required this.markers,
    required this.playedColor,
    required this.unplayedColor,
    required this.playheadColor,
    required this.markerColor,
    required this.silenceOverlayColor,
  });

  final List<double> bars;
  final double progress;
  final int durationMs;
  final List<TimelineMarker> markers;
  final Color playedColor;
  final Color unplayedColor;
  final Color playheadColor;
  final Color markerColor;
  final Color silenceOverlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    // Highlight silence ranges subtly behind bars.
    if (durationMs > 0) {
      final rangePaint = Paint()..color = silenceOverlayColor;
      for (final m in markers) {
        if (m.type != MarkerType.silence) continue;
        final startX = (m.startMs / durationMs).clamp(0.0, 1.0) * size.width;
        final endX =
            (m.effectiveEndMs / durationMs).clamp(0.0, 1.0) * size.width;
        if (endX > startX) {
          canvas.drawRect(
            Rect.fromLTRB(startX, 4, endX, size.height - 4),
            rangePaint,
          );
        }
      }
    }

    final centerY = size.height / 2;
    final step = size.width / bars.length;
    final barWidth = math.max(1.8, step * 0.56);

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final playheadX = (progress * size.width).clamp(0.0, size.width);

    for (var i = 0; i < bars.length; i++) {
      final x = i * step + step / 2;
      final minHalf = 1.5;
      final maxHalf = (size.height / 2) - 8;
      final half = minHalf + bars[i] * (maxHalf - minHalf);
      final paint = x <= playheadX ? playedPaint : unplayedPaint;
      canvas.drawLine(
        Offset(x, centerY - half),
        Offset(x, centerY + half),
        paint,
      );
    }

    // Draw marker / gap ticks.
    if (durationMs > 0) {
      final tickPaint = Paint()
        ..color = markerColor
        ..strokeWidth = 1.8;
      for (final m in markers) {
        final x = (m.startMs / durationMs).clamp(0.0, 1.0) * size.width;
        canvas.drawLine(Offset(x, 0), Offset(x, 10), tickPaint);
        canvas.drawCircle(Offset(x, 3), 2.5, tickPaint);
      }
    }

    // Draw playhead.
    final headPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(playheadX, 2),
      Offset(playheadX, size.height - 2),
      headPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReplayWaveformPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.progress != progress ||
        oldDelegate.durationMs != durationMs ||
        oldDelegate.markers != markers;
  }
}

class _MarkerJumpChip extends StatelessWidget {
  const _MarkerJumpChip({
    required this.marker,
    required this.onTap,
  });

  final TimelineMarker marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final text = '${marker.shortTickLabel} ${marker.formattedStart}';
    return Semantics(
      button: true,
      label: 'Jump to ${marker.displayLabel}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MinuteRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MinuteRadii.sm),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  marker.type == MarkerType.marker
                      ? Icons.bookmark_outline
                      : (marker.type == MarkerType.callGap
                          ? Icons.call_outlined
                          : Icons.volume_off_outlined),
                  size: 16,
                  color: c.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
