import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:altaria/data/models.dart';
import 'package:altaria/ui/track_tile.dart';

Track track({
  required int id,
  required String title,
  bool streamable = true,
  List<Map<String, dynamic>> transcodings = const [],
}) {
  return Track.fromJson({
    'id': id,
    'title': title,
    'duration': 125000,
    'streamable': streamable,
    'media': {'transcodings': transcodings},
  });
}

void main() {
  testWidgets('marks a track without a clear stream and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTile(
            track: track(id: 1, title: 'Blocked'),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('NOT STREAMABLE'), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);

    await tester.tap(find.byType(TrackTile));
    expect(taps, 0);
  });

  testWidgets('plays a track with a clear stream and shows its duration', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackTile(
            track: track(
              id: 2,
              title: 'Playable',
              transcodings: [
                {
                  'url': 'https://api.test/media/hls',
                  'preset': 'aac_160k',
                  'format': {'protocol': 'hls'},
                },
              ],
            ),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('2:05'), findsOneWidget);
    await tester.tap(find.byType(TrackTile));
    expect(taps, 1);
  });
}
