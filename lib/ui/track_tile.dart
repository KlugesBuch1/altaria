import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme.dart';
import 'format.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isCurrent = false,
    this.trailing,
  });

  final Track track;
  final VoidCallback onTap;
  final bool isCurrent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unplayable = !track.isPlayable;
    return InkWell(
      onTap: unplayable ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Opacity(
              opacity: unplayable ? 0.38 : 1,
              child: _Artwork(track: track),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: unplayable
                          ? muted
                          : isCurrent
                          ? rose
                          : cream,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (unplayable) ...[
                        Text(
                          'NOT STREAMABLE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                            fontSize: 8,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (track.isPreview) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: wine,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PREVIEW',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cream,
                              fontSize: 8,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!unplayable)
                        Text(
                          formatDuration(track.duration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  unplayable
                      ? Icons.block_rounded
                      : isCurrent
                      ? Icons.graphic_eq_rounded
                      : Icons.play_arrow_rounded,
                  color: unplayable
                      ? muted.withValues(alpha: 0.5)
                      : isCurrent
                      ? rose
                      : muted,
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final url = track.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 54,
        height: 54,
        child: url == null
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: panelHigh,
      child: const Icon(Icons.music_note_rounded, color: muted, size: 22),
    );
  }
}
