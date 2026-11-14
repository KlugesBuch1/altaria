import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/soundcloud_client.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'current_track.dart';
import 'track_tile.dart';
import 'wordmark.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
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
      final page = await api.charts();
      if (!mounted) return;
      setState(() {
        _tracks = page.collection.map((entry) => entry.track).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the charts.';
        _loading = false;
      });
    }
  }

  Future<void> _play(int index) async {
    final player = _player;
    if (player == null || index < 0 || index >= _tracks.length) return;
    final selected = _tracks[index];
    if (!selected.isPlayable) return;
    final playable = _tracks
        .where((track) => track.isPlayable)
        .toList(growable: false);
    final start = playable.indexWhere((track) => track.id == selected.id);
    await player.playTracks(playable, startIndex: start < 0 ? 0 : start);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wordmark(),
          const SizedBox(height: 24),
          Text(
            'Trending now',
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: cream, height: 1.05),
          ),
          const SizedBox(height: 6),
          Text(
            'The public charts, straight from SoundCloud.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 18),
          Expanded(child: _body()),
        ],
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
        child: Text('No charts right now.', style: TextStyle(color: muted)),
      );
    }
    final player = _player;
    if (player == null) return const SizedBox.shrink();
    return CurrentTrackBuilder(
      handler: player,
      builder: (context, currentId) => RefreshIndicator(
        onRefresh: _load,
        color: rose,
        backgroundColor: panelHigh,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 32),
          physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}
