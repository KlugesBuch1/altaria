import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/soundcloud_client.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'artwork.dart';
import 'current_track.dart';
import 'format.dart';
import 'track_tile.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key, required this.user});

  final User user;

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  SoundCloudClient? _api;
  AltariaAudioHandler? _player;

  List<Track> _tracks = const [];
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
      final page = await api.userTracks(widget.user.id);
      if (!mounted) return;
      setState(() {
        _tracks = page.collection;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this artist.';
        _loading = false;
      });
    }
  }

  Future<void> _play(int index) async {
    final player = _player;
    if (player == null || index < 0 || index >= _tracks.length) return;
    final selected = _tracks[index];
    if (!selected.isPlayable) return;
    final playable = _tracks.where((track) => track.isPlayable).toList();
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: bone),
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
                  Artwork(url: widget.user.imageUrl, size: 92, radius: 46),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARTIST',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.user.username,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: bone,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatCount(widget.user.followersCount)} followers',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'TRACKS',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: muted, size: 38),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: muted)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_tracks.isEmpty) {
      return const Center(
        child: Text('No public tracks.', style: TextStyle(color: muted)),
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
