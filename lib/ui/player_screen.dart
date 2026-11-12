import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'artwork.dart';
import 'format.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final handler = AppScope.of(context).player;
    return Scaffold(
      backgroundColor: ink,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.1,
            colors: [frost.withValues(alpha: 0.12), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<MediaItem?>(
            stream: handler.mediaItem,
            initialData: handler.mediaItem.value,
            builder: (context, snapshot) {
              final item = snapshot.data;
              if (item == null) return const _EmptyPlayer();
              final track = handler.currentTrack;
              final artUrl = track?.imageUrl ?? item.artUri?.toString();
              return Column(
                children: [
                  _Header(onClose: () => Navigator.of(context).pop()),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _Cover(url: artUrl),
                          const SizedBox(height: 32),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: bone, height: 1.2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.artist ?? '',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: muted),
                          ),
                          if (track?.isPreview ?? false) ...[
                            const SizedBox(height: 10),
                            const _PreviewBadge(),
                          ],
                          const SizedBox(height: 26),
                          _SeekBar(
                            handler: handler,
                            item: item,
                            dragPosition: _dragPosition,
                            onDrag: (value) =>
                                setState(() => _dragPosition = value),
                            onSeek: (value) {
                              handler.seek(value);
                              setState(() => _dragPosition = null);
                            },
                          ),
                          const SizedBox(height: 20),
                          _Transport(handler: handler),
                          const SizedBox(height: 30),
                          _QueueList(handler: handler),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.handler,
    required this.item,
    required this.dragPosition,
    required this.onDrag,
    required this.onSeek,
  });

  final AltariaAudioHandler handler;
  final MediaItem item;
  final Duration? dragPosition;
  final ValueChanged<Duration> onDrag;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: handler.player.durationStream,
      initialData: handler.player.duration,
      builder: (context, durationSnapshot) {
        final total = durationSnapshot.data ?? item.duration ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: handler.player.positionStream,
          initialData: handler.player.position,
          builder: (context, positionSnapshot) {
            final position =
                dragPosition ?? positionSnapshot.data ?? Duration.zero;
            final totalMs = total.inMilliseconds;
            final max = totalMs > 0 ? totalMs.toDouble() : 1.0;
            final value = position.inMilliseconds.clamp(0, totalMs).toDouble();
            final style = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
            return Column(
              children: [
                Slider(
                  value: value,
                  max: max,
                  onChanged: (next) =>
                      onDrag(Duration(milliseconds: next.round())),
                  onChangeEnd: (next) =>
                      onSeek(Duration(milliseconds: next.round())),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position), style: style),
                      Text(formatDuration(total), style: style),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ember.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '30 SECOND PREVIEW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ember),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: bone),
          ),
          const Spacer(),
          Text(
            'NOW PLAYING',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: muted, letterSpacing: 1.8),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = (width - 72).clamp(180.0, 340.0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Artwork(url: url, size: size, radius: 20),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.handler});

  final AltariaAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous',
          onPressed: handler.skipToPrevious,
          iconSize: 38,
          color: bone,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: 28),
        _PlayButton(handler: handler),
        const SizedBox(width: 28),
        IconButton(
          tooltip: 'Next',
          onPressed: handler.skipToNext,
          iconSize: 38,
          color: bone,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.handler});

  final AltariaAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final queue = handler.playQueue;
    final tracks = queue.tracks;
    final index = queue.index;
    if (index + 1 >= tracks.length) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('UP NEXT', style: style?.copyWith(color: muted)),
            const Spacer(),
            Text(
              '${tracks.length - index - 1}',
              style: style?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = index + 1; i < tracks.length; i++)
          _QueueRow(track: tracks[i], onTap: () => handler.playAt(i)),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Artwork(url: track.thumbnailUrl, size: 40, radius: 7),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: bone),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatDuration(track.duration),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.handler});

  final AltariaAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      initialData: handler.playbackState.value,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final loading =
            state?.processingState == AudioProcessingState.loading ||
            state?.processingState == AudioProcessingState.buffering;
        return SizedBox(
          width: 76,
          height: 76,
          child: Material(
            color: frost,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: loading
                  ? null
                  : () {
                      if (playing) {
                        handler.pause();
                      } else {
                        handler.play();
                      }
                    },
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: ink,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 40,
                        color: ink,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Nothing playing', style: TextStyle(color: muted)),
    );
  }
}
