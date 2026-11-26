import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/recording_item.dart';

/// Manages `just_audio` playback and audio session interruptions
/// (e.g. pausing automatically when headphones are unplugged).
class PlaybackController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<void>? _noisySub;

  RecordingItem? _currentItem;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  RecordingItem? get currentItem => _currentItem;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
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

  Future<void> togglePlay(RecordingItem item) async {
    _errorMessage = null;
    try {
      if (_currentItem?.id == item.id) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        return;
      }

      _currentItem = item;
      _position = Duration.zero;
      _duration = item.duration;
      _isLoading = true;
      notifyListeners();

      await _player.setFilePath(item.filePath);
      _duration = _player.duration ?? item.duration;
      await _player.play();
    } catch (e) {
      _errorMessage = 'Playback error: $e';
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seek(Duration target) async {
    if (_currentItem == null) return;
    await _player.seek(target);
  }

  Future<void> stopIfCurrent(RecordingItem item) async {
    if (_currentItem?.id != item.id) return;
    await stop();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentItem = null;
    _isPlaying = false;
    _isLoading = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _noisySub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
