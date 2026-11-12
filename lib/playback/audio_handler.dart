import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';
import '../data/soundcloud_client.dart';
import 'queue.dart';

class AltariaAudioHandler extends BaseAudioHandler with SeekHandler {
  AltariaAudioHandler({required this.api}) {
    _player.playbackEventStream.listen(
      (_) => _publishState(),
      onError: (Object error, StackTrace _) =>
          _report('Playback failed: $error'),
    );
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) unawaited(_advance());
    });
    _publishState();
  }

  final SoundCloudClient api;
  final AudioPlayer _player = AudioPlayer();
  final Queue playQueue = Queue();
  final _errors = StreamController<String>.broadcast();

  bool _loading = false;
  bool _changing = false;
  int _loadToken = 0;

  Stream<String> get errors => _errors.stream;

  AudioPlayer get player => _player;

  Track? get currentTrack => playQueue.current;

  bool get isLoading => _loading;

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    final selected = tracks[index];
    if (selected.id == playQueue.current?.id && _player.audioSource != null) {
      if (!_player.playing) unawaited(_player.play());
      return;
    }
    playQueue.replace(tracks, startIndex: index);
    await _loadCurrent(autoPlay: true);
  }

  Future<void> playAt(int index) async {
    if (playQueue.isEmpty) return;
    playQueue.jumpTo(index);
    await _loadCurrent(autoPlay: true);
  }

  @override
  Future<void> play() async {
    if (playQueue.current == null) return;
    if (_player.audioSource == null) {
      await _loadCurrent(autoPlay: true);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _advance();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3) ||
        !playQueue.hasPrevious) {
      await _player.seek(Duration.zero);
      return;
    }
    playQueue.movePrevious();
    await _loadCurrent(autoPlay: true);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    _publishState();
  }

  Future<void> _advance() async {
    if (_changing) return;
    _changing = true;
    try {
      if (!playQueue.hasNext) {
        await _player.pause();
        return;
      }
      playQueue.moveNext();
      await _loadCurrent(autoPlay: true);
    } finally {
      _changing = false;
    }
  }

  Future<void> _loadCurrent({required bool autoPlay}) async {
    final track = playQueue.current;
    if (track == null) return;
    final token = ++_loadToken;
    _loading = true;
    mediaItem.add(_itemFor(track));
    _publishQueue();
    _publishState();
    try {
      final url = await api.resolveStream(track);
      await _player.setUrl(url);
      if (token != _loadToken) return;
      _loading = false;
      _publishState();
      if (autoPlay) unawaited(_player.play());
    } catch (error) {
      if (token != _loadToken) return;
      _loading = false;
      _publishState();
      _report(_messageFor(error));
      debugPrint('altaria playback: $error');
    }
  }

  void _publishQueue() {
    queue.add(playQueue.tracks.map(_itemFor).toList(growable: false));
  }

  void _publishState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _processingState(),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: playQueue.isEmpty ? null : playQueue.index,
      ),
    );
  }

  AudioProcessingState _processingState() {
    if (_loading) return AudioProcessingState.loading;
    return switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  MediaItem _itemFor(Track track) {
    final artwork = track.artworkUrl;
    return MediaItem(
      id: '${track.id}',
      album: 'SoundCloud',
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      artUri: artwork == null ? null : Uri.tryParse(artwork),
    );
  }

  String _messageFor(Object error) {
    if (error is UnplayableTrackException) return error.message;
    if (error is SoundCloudException && error.status == 401) {
      return 'SoundCloud rejected the request.';
    }
    return 'Could not load this track.';
  }

  void _report(String message) {
    if (!_errors.isClosed) _errors.add(message);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }
}
