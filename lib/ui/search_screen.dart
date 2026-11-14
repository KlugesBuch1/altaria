import 'dart:async';

import 'package:material_ui/material_ui.dart' hide Page;

import '../app_scope.dart';
import '../data/models.dart';
import '../data/soundcloud_client.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'current_track.dart';
import 'playlist_screen.dart';
import 'result_tiles.dart';
import 'track_tile.dart';
import 'user_screen.dart';

enum SearchKind { tracks, playlists, people }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  SoundCloudClient? _api;
  AltariaAudioHandler? _player;

  SearchKind _kind = SearchKind.tracks;
  List<Track> _tracks = const [];
  List<Playlist> _playlists = const [];
  List<User> _users = const [];
  Page<Track>? _trackPage;
  String _query = '';
  String? _error;
  bool _searching = false;
  bool _loadingMore = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

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
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _kind != SearchKind.tracks) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _tracks = const [];
        _playlists = const [];
        _users = const [];
        _trackPage = null;
        _error = null;
        _searching = false;
        _loadingMore = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  void _setKind(SearchKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _tracks = const [];
      _playlists = const [];
      _users = const [];
      _trackPage = null;
      _error = null;
      _loadingMore = false;
    });
    if (_query.isNotEmpty) _search(_query);
  }

  Future<void> _search(String query) async {
    final api = _api;
    if (api == null || query.isEmpty) return;
    final generation = ++_generation;
    final kind = _kind;
    setState(() {
      _query = query;
      _tracks = const [];
      _playlists = const [];
      _users = const [];
      _trackPage = null;
      _searching = true;
      _error = null;
      _loadingMore = false;
    });
    _focus.unfocus();
    try {
      List<Track>? tracks;
      List<Playlist>? playlists;
      List<User>? users;
      Page<Track>? trackPage;
      if (kind == SearchKind.tracks) {
        final page = await api.searchTracks(query, limit: 40);
        tracks = page.collection;
        trackPage = page;
      } else if (kind == SearchKind.playlists) {
        final page = await api.searchPlaylists(query, limit: 40);
        playlists = page.collection;
      } else {
        final page = await api.searchUsers(query, limit: 40);
        users = page.collection;
      }
      if (!mounted || generation != _generation || kind != _kind) return;
      setState(() {
        if (tracks != null) _tracks = tracks;
        if (playlists != null) _playlists = playlists;
        if (users != null) _users = users;
        _trackPage = trackPage;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation || kind != _kind) return;
      setState(() {
        _error = _friendlyError(error);
        _searching = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final api = _api;
    final page = _trackPage;
    if (api == null ||
        page == null ||
        page.nextHref == null ||
        _loadingMore ||
        _searching) {
      return;
    }
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final next = await api.nextPage(page, Track.fromJson);
      if (!mounted || generation != _generation) return;
      if (next == null) {
        setState(() => _loadingMore = false);
        return;
      }
      final seen = _tracks.map((track) => track.id).toSet();
      final merged = [
        ..._tracks,
        ...next.collection.where((track) => seen.add(track.id)),
      ];
      setState(() {
        _tracks = merged;
        _trackPage = next;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more tracks.')),
      );
    }
  }

  void _useSuggestion(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    if (_kind != SearchKind.tracks) {
      _kind = SearchKind.tracks;
    }
    _search(query);
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

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistScreen(playlist: playlist),
      ),
    );
  }

  void _openUser(User user) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => UserScreen(user: user)));
  }

  int get _resultCount => switch (_kind) {
    SearchKind.tracks => _tracks.length,
    SearchKind.playlists => _playlists.length,
    SearchKind.people => _users.length,
  };

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    final count = _resultCount;
    final resultLabel = '$count ${count == 1 ? 'RESULT' : 'RESULTS'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              hintText: 'Search tracks, sets and artists',
              prefixIcon: const Icon(Icons.search_rounded, color: rose),
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
          if (hasText) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _KindChip(
                  label: 'Tracks',
                  selected: _kind == SearchKind.tracks,
                  onTap: () => _setKind(SearchKind.tracks),
                ),
                const SizedBox(width: 8),
                _KindChip(
                  label: 'Sets',
                  selected: _kind == SearchKind.playlists,
                  onTap: () => _setKind(SearchKind.playlists),
                ),
                const SizedBox(width: 8),
                _KindChip(
                  label: 'People',
                  selected: _kind == SearchKind.people,
                  onTap: () => _setKind(SearchKind.people),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 18),
          if (_resultCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                resultLabel,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted),
              ),
            ),
          Expanded(child: _body(hasText)),
        ],
      ),
    );
  }

  Widget _body(bool hasText) {
    if (!hasText && _query.isEmpty) {
      return _SearchIntro(onSuggestion: _useSuggestion);
    }
    if (_searching && _resultCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _search(_query));
    }
    return switch (_kind) {
      SearchKind.tracks => _trackBody(),
      SearchKind.playlists => _playlistBody(),
      SearchKind.people => _peopleBody(),
    };
  }

  Widget _trackBody() {
    if (_tracks.isEmpty) {
      return _EmptyState(query: _query, noun: 'tracks');
    }
    final player = _player;
    if (player == null) return const SizedBox.shrink();
    return CurrentTrackBuilder(
      handler: player,
      builder: (context, currentId) => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 120),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _tracks.length + 1,
        itemBuilder: (context, index) {
          if (index == _tracks.length) {
            if (_trackPage?.nextHref == null) {
              return const SizedBox(height: 28);
            }
            if (!_loadingMore) return const SizedBox(height: 28);
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
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

  Widget _playlistBody() {
    if (_playlists.isEmpty) {
      return _EmptyState(query: _query, noun: 'sets');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return PlaylistTile(
          playlist: playlist,
          onTap: () => _openPlaylist(playlist),
        );
      },
    );
  }

  Widget _peopleBody() {
    if (_users.isEmpty) {
      return _EmptyState(query: _query, noun: 'artists');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return UserTile(user: user, onTap: () => _openUser(user));
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

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: panel,
      selectedColor: wine,
      side: BorderSide(color: selected ? wine : const Color(0xFF3D2421)),
      labelStyle: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: cream, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );
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
          Text(
            'Find something\nto keep.',
            style: theme.textTheme.displaySmall?.copyWith(
              height: 1.08,
              color: cream,
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
                  side: const BorderSide(color: Color(0xFF3D2421)),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(color: cream),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.noun});

  final String query;
  final String noun;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, color: muted, size: 38),
          const SizedBox(height: 12),
          Text(
            'No $noun for "$query"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Try a shorter search.', style: TextStyle(color: muted)),
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
