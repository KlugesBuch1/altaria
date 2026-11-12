import 'package:flutter_test/flutter_test.dart';

import 'package:altaria/data/models.dart';

void main() {
  test('parses a track and its user', () {
    final track = Track.fromJson({
      'id': 1,
      'title': 'Memory Signal',
      'duration': 285871,
      'full_duration': 285871,
      'streamable': true,
      'policy': 'ALLOW',
      'genre': 'Electronic',
      'user': {
        'id': 2,
        'username': 'bonobo',
        'avatar_url': 'https://i1.sndcdn.com/avatars-x-large.jpg',
      },
      'artwork_url': 'https://i1.sndcdn.com/artworks-y-large.jpg',
      'media': {
        'transcodings': [
          {
            'url': 'https://api.test/media/hls',
            'preset': 'aac_160k',
            'snipped': false,
            'format': {'protocol': 'hls'},
          },
        ],
      },
    });

    expect(track.title, 'Memory Signal');
    expect(track.artist, 'bonobo');
    expect(track.duration, const Duration(milliseconds: 285871));
    expect(track.imageUrl, 'https://i1.sndcdn.com/artworks-y-t500x500.jpg');
    expect(track.isPlayable, isTrue);
  });

  test('orders progressive before hls and fixed rates before abr', () {
    final track = Track.fromJson({
      'id': 1,
      'title': 'Order',
      'media': {
        'transcodings': [
          {
            'url': 'https://api.test/abr',
            'preset': 'abr_sq',
            'snipped': false,
            'format': {'protocol': 'hls'},
          },
          {
            'url': 'https://api.test/96',
            'preset': 'aac_96k',
            'snipped': false,
            'format': {'protocol': 'hls'},
          },
          {
            'url': 'https://api.test/160',
            'preset': 'aac_160k',
            'snipped': false,
            'format': {'protocol': 'hls'},
          },
          {
            'url': 'https://api.test/progressive',
            'preset': 'mp3_0_0',
            'snipped': false,
            'format': {'protocol': 'progressive'},
          },
          {
            'url': 'https://api.test/encrypted',
            'preset': 'aac_160k',
            'snipped': false,
            'format': {'protocol': 'ctr-encrypted-hls'},
          },
        ],
      },
    });

    expect(
      track.playbackOrder.map((item) => item.url).toList(),
      [
        'https://api.test/progressive',
        'https://api.test/160',
        'https://api.test/96',
        'https://api.test/abr',
      ],
    );
  });

  test('falls back to a snipped rendition and marks it as a preview', () {
    final track = Track.fromJson({
      'id': 1,
      'title': 'Preview',
      'policy': 'SNIP',
      'duration': 30000,
      'full_duration': 268929,
      'media': {
        'transcodings': [
          {
            'url': 'https://api.test/preview',
            'snipped': true,
            'format': {'protocol': 'progressive'},
          },
        ],
      },
    });

    expect(track.isPreview, isTrue);
    expect(track.isPlayable, isTrue);
    expect(track.playbackOrder.single.url, 'https://api.test/preview');
  });

  test('treats encrypted-only tracks as unplayable', () {
    final track = Track.fromJson({
      'id': 1,
      'title': 'Encrypted',
      'media': {
        'transcodings': [
          {
            'url': 'https://api.test/encrypted',
            'format': {'protocol': 'ctr-encrypted-hls'},
          },
        ],
      },
    });

    expect(track.isPlayable, isFalse);
  });

  test('parses a playlist page and charts', () {
    final playlist = Playlist.fromJson({
      'id': 9,
      'title': 'A set',
      'track_count': 1,
      'is_album': false,
      'user': {'id': 1, 'username': 'Curator'},
      'tracks': [
        {'id': 2, 'title': 'Inside'},
      ],
    });
    expect(playlist.tracks.single.title, 'Inside');
    expect(playlist.artist, 'Curator');

    final chart = ChartPage.fromJson({
      'collection': [
        {
          'score': 0.8,
          'track': {'id': 3, 'title': 'Charted'},
        },
      ],
    });
    expect(chart.collection.single.track.title, 'Charted');
    expect(chart.collection.single.score, 0.8);
  });

  test('keeps artwork urls that have no known suffix', () {
    expect(artworkAt('https://i1.sndcdn.com/artworks-x.jpg'),
        'https://i1.sndcdn.com/artworks-x.jpg');
    expect(artworkAt(null), isNull);
  });
}
