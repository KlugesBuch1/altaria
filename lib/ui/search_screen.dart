import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/soundcloud_client.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'track_tile.dart';
import 'wordmark.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  SoundCloudClient? _api;
  AltariaAudioHandler? _player;

  List<Track> _tracks = const [];
  String _query = '';
  String? _error;
  bool _searching = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _api = scope.api;
    _player = scope.player;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _tracks = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final api = _api;
    if (api == null || query.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _query = query;
      _searching = true;
      _error = null;
    });
    _focus.unfocus();
    try {
      final page = await api.searchTracks(query, limit: 40);
      if (!mounted || generation != _generation) return;
      setState(() {
        _tracks = page.collection;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = _friendlyError(error);
        _searching = false;
      });
    }
  }

  void _useSuggestion(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _search(query);
  }

  Future<void> _play(int index) async {
    final player = _player;
    if (player == null || _tracks.isEmpty) return;
    await player.playTracks(_tracks, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wordmark(),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (value) {
              _debounce?.cancel();
              _search(value.trim());
            },
            decoration: InputDecoration(
              hintText: 'Search tracks and artists',
              prefixIcon: const Icon(Icons.search_rounded, color: muted),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, color: muted),
                      onPressed: () {
                        _debounce?.cancel();
                        _controller.clear();
                        _onChanged('');
                        _focus.requestFocus();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: _body(hasText)),
        ],
      ),
    );
  }

  Widget _body(bool hasText) {
    if (!hasText && _query.isEmpty) {
      return _SearchIntro(onSuggestion: _useSuggestion);
    }
    if (_searching && _tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _search(_query));
    }
    if (_tracks.isEmpty) {
      return _EmptyState(query: _query);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        return TrackTile(
          track: track,
          onTap: () => _play(index),
        );
      },
    );
  }

  String _friendlyError(Object error) {
    if (error is SoundCloudException && error.status == 401) {
      return 'SoundCloud rejected the request. Try again in a moment.';
    }
    return 'Could not reach SoundCloud. Check the connection and retry.';
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.graphic_eq_rounded, size: 38, color: frost.withValues(alpha: 0.7)),
          const SizedBox(height: 18),
          Text(
            'Find something\nto keep.',
            style: theme.textTheme.displaySmall?.copyWith(
              height: 1.08,
              color: bone,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Search the public catalogue. No account, no feed, no ads.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in const [
                'beat tape',
                'ambient',
                'jazz',
                'lofi',
                'field recording',
              ])
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () => onSuggestion(suggestion),
                  backgroundColor: panel,
                  side: const BorderSide(color: Color(0xFF1D2832)),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(color: bone),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, color: muted, size: 38),
          const SizedBox(height: 12),
          Text(
            'Nothing for "$query"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a shorter search.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
