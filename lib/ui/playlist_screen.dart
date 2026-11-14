import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/soundcloud_client.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'artwork.dart';
import 'current_track.dart';
import 'track_tile.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  SoundCloudClient? _api;
  AltariaAudioHandler? _player;

  Playlist? _full;
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _api = scope.api;
    _player = scope.player;
    if (!_started) {
      _started = true;
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    final api = _api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final playlist = await api.playlist(widget.playlist.id);
      if (!mounted) return;
      setState(() {
        _full = playlist;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this set.';
        _loading = false;
      });
    }
  }

  List<Track> get _tracks => _full?.tracks ?? const [];

  Future<void> _play(int index) async {
    final player = _player;
    final tracks = _tracks;
    if (player == null || index < 0 || index >= tracks.length) return;
    final selected = tracks[index];
    if (!selected.isPlayable) return;
    final playable = tracks.where((track) => track.isPlayable).toList();
    final start = playable.indexWhere((track) => track.id == selected.id);
    await player.playTracks(playable, startIndex: start < 0 ? 0 : start);
  }

  Future<void> _playAll() async {
    final playable = _tracks.where((track) => track.isPlayable).toList();
    if (playable.isEmpty) return;
    await _player?.playTracks(playable);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _full ?? widget.playlist;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: cream),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Artwork(url: playlist.imageUrl, size: 104, radius: 14),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.isAlbum ? 'ALBUM' : 'SET',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          playlist.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: cream,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          playlist.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        if (_tracks.isNotEmpty)
                          Text(
                            '${_tracks.length} tracks',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_tracks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _playAll,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play all'),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _PlaylistError(message: _error!, onRetry: _load);
    }
    if (_tracks.isEmpty) {
      return const Center(
        child: Text('This set has no tracks.', style: TextStyle(color: muted)),
      );
    }
    final player = _player;
    if (player == null) return const SizedBox.shrink();
    return CurrentTrackBuilder(
      handler: player,
      builder: (context, currentId) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _tracks.length,
        itemBuilder: (context, index) {
          final track = _tracks[index];
          return TrackTile(
            track: track,
            isCurrent: track.id == currentId,
            onTap: () => _play(index),
          );
        },
      ),
    );
  }
}

class _PlaylistError extends StatelessWidget {
  const _PlaylistError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: muted, size: 38),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
