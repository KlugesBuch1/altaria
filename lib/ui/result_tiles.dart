import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme.dart';
import 'artwork.dart';
import 'format.dart';

class PlaylistTile extends StatelessWidget {
  const PlaylistTile({super.key, required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = playlist.trackCount;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Artwork(url: playlist.imageUrl, size: 54, radius: 9),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: bone,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count > 0
                        ? '${playlist.artist} · $count tracks'
                        : playlist.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Artwork(url: user.imageUrl, size: 52, radius: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: bone,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatCount(user.followersCount)} followers',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted, size: 22),
          ],
        ),
      ),
    );
  }
}
