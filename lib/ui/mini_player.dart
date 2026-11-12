import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../playback/audio_handler.dart';
import '../theme.dart';
import 'artwork.dart';
import 'player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final handler = AppScope.of(context).player;
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      initialData: handler.mediaItem.value,
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data;
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          initialData: handler.playbackState.value,
          builder: (context, stateSnapshot) {
            return _Bar(
              handler: handler,
              item: item,
              state: stateSnapshot.data,
            );
          },
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.handler, required this.item, required this.state});

  final AltariaAudioHandler handler;
  final MediaItem item;
  final PlaybackState? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = state?.playing ?? false;
    final loading =
        state?.processingState == AudioProcessingState.loading ||
        state?.processingState == AudioProcessingState.buffering;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: panelHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const PlayerScreen())),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                child: Row(
                  children: [
                    Artwork(url: item.artUri?.toString(), size: 42, radius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: bone,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: bone,
                        ),
                        onPressed: () {
                          if (playing) {
                            handler.pause();
                          } else {
                            handler.play();
                          }
                        },
                      ),
                    IconButton(
                      tooltip: 'Next',
                      icon: const Icon(Icons.skip_next_rounded, color: muted),
                      onPressed: handler.skipToNext,
                    ),
                  ],
                ),
              ),
              StreamBuilder<Duration>(
                stream: handler.player.positionStream,
                initialData: handler.player.position,
                builder: (context, positionSnapshot) {
                  final total = item.duration ?? Duration.zero;
                  final position = positionSnapshot.data ?? Duration.zero;
                  final value = total.inMilliseconds <= 0
                      ? 0.0
                      : (position.inMilliseconds / total.inMilliseconds).clamp(
                          0.0,
                          1.0,
                        );
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: frost,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
