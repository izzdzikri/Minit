import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Manages `just_audio` playback, speed control (`0.75x`–`2.0x`), +/-10s skip,
/// and audio-session interruptions (e.g. pausing when headphones unplug).
class PlaybackController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<void>? _noisySub;

  String? _currentMeetingId;
  String? _currentPath;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  String? _errorMessage;
  bool _isDisposed = false;

  String? get currentMeetingId => _currentMeetingId;
  String? get currentPath => _currentPath;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      _noisySub = session.becomingNoisyEventStream.listen((_) {
        if (_player.playing) {
          unawaited(_player.pause());
        }
      });
    } catch (_) {
      // Non-Android / unit test environments may lack audio_session platform impl.
    }

    _playerStateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing &&
          state.processingState != ProcessingState.completed;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.pause());
        unawaited(_player.seek(Duration.zero));
        _position = Duration.zero;
      }
      notifyListeners();
    });

    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  /// Preloads [filePath] for [meetingId] without auto-playing, optionally
  /// seeking to [initialSeek].
  Future<void> loadMeetingAudio({
    required String meetingId,
    required String? filePath,
    required Duration fallbackDuration,
    Duration? initialSeek,
  }) async {
    _errorMessage = null;
    if (filePath == null || filePath.isEmpty || !File(filePath).existsSync()) {
      if (_currentMeetingId != meetingId) {
        await stop();
      }
      _currentMeetingId = meetingId;
      _currentPath = null;
      _duration = fallbackDuration;
      _position = initialSeek ?? Duration.zero;
      notifyListeners();
      return;
    }

    if (_currentMeetingId == meetingId && _currentPath == filePath) {
      if (initialSeek != null) {
        await seek(initialSeek);
      }
      return;
    }

    try {
      _currentMeetingId = meetingId;
      _currentPath = filePath;
      _position = initialSeek ?? Duration.zero;
      _duration = fallbackDuration;
      _isLoading = true;
      notifyListeners();

      await _player.setFilePath(filePath);
      await _player.setSpeed(_speed);
      _duration = _player.duration ?? fallbackDuration;
      if (initialSeek != null && initialSeek > Duration.zero) {
        await _player.seek(initialSeek);
        _position = initialSeek;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not load audio file.';
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
      assert(() {
        debugPrint('PlaybackController load error: $e');
        return true;
      }());
    }
  }

  Future<void> togglePlay({
    required String meetingId,
    required String? filePath,
    required Duration fallbackDuration,
  }) async {
    _errorMessage = null;
    if (filePath == null || filePath.isEmpty || !File(filePath).existsSync()) {
      _errorMessage = 'No local audio file attached to this demo meeting.';
      notifyListeners();
      return;
    }

    if (_currentMeetingId != meetingId || _currentPath != filePath) {
      await loadMeetingAudio(
        meetingId: meetingId,
        filePath: filePath,
        fallbackDuration: fallbackDuration,
      );
      if (_errorMessage != null) return;
    }

    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e) {
      _errorMessage = 'Playback error: could not play this file.';
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seek(Duration target) async {
    final maxDur = _duration > Duration.zero ? _duration : target;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, maxDur.inMilliseconds),
    );
    _position = clamped;
    notifyListeners();
    if (_currentPath != null) {
      await _player.seek(clamped);
    }
  }

  Future<void> skipBy(Duration delta) async {
    await seek(_position + delta);
  }

  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed.clamp(0.75, 2.0);
    if (_currentPath != null) {
      await _player.setSpeed(_speed);
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _player.stop();
    } catch (_) {}
    if (_isDisposed) return;
    _currentMeetingId = null;
    _currentPath = null;
    _isPlaying = false;
    _isLoading = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _noisySub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
