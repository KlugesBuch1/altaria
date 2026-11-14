// ignore_for_file: avoid_print

import 'package:altaria/data/soundcloud_client.dart';

/// Hits the measured API the same way the app does. Run with `dart run tool/smoke.dart`.
Future<void> main() async {
  final api = SoundCloudClient();
  try {
    final page = await api.searchTracks('beat tape', limit: 10);
    print('search: ${page.collection.length} results');
    for (final track in page.collection.take(3)) {
      final protocols = track.transcodings
          .map((item) => item.protocol ?? '?')
          .toSet()
          .join(', ');
      print('  ${track.id} ${track.title} [$protocols]');
    }
    final playable = page.collection.where((track) => track.isPlayable).first;
    final stream = await api.resolveStream(playable);
    final uri = Uri.parse(stream);
    print('resolved ${playable.title} -> ${uri.host}${uri.path}');
  } finally {
    api.close();
  }
}
