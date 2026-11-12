import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:altaria/data/models.dart';
import 'package:altaria/data/soundcloud_client.dart';

const staleId = '0123456789abcdefghijklmnopqrstuv';
const freshId = 'zyxwvutsrqponmlkjihgfedcba987654';

Map<String, dynamic> trackJson(int id, {String title = 'A track'}) => {
      'id': id,
      'title': title,
      'duration': 120000,
      'full_duration': 120000,
      'streamable': true,
      'policy': 'ALLOW',
      'user': {'id': 7, 'username': 'Artist'},
      'artwork_url': 'https://i1.sndcdn.com/artworks-x-large.jpg',
      'media': {
        'transcodings': [
          {
            'url': 'https://api.test/media/$id/hls',
            'preset': 'aac_160k',
            'snipped': false,
            'format': {'protocol': 'hls', 'mime_type': 'audio/mp4'},
          },
        ],
      },
    };

String searchBody({
  String? nextHref,
  List<Map<String, dynamic>>? collection,
}) =>
    jsonEncode({
      'collection': collection ?? [trackJson(1)],
      'total_results': 1,
      'next_href': nextHref,
    });

void main() {
  test('discovers a client id and sends it with search', () async {
    final requests = <Uri>[];
    final http.Client mock = MockClient((request) async {
      requests.add(request.url);
      if (request.url.host == 'player.test') {
        return http.Response(
          '<script src="https://assets.test/app.js"></script>',
          200,
        );
      }
      if (request.url.host == 'assets.test') {
        return http.Response('e.client_id:"$freshId",t', 200);
      }
      return http.Response(searchBody(), 200);
    });
    final client = SoundCloudClient(
      httpClient: mock,
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );

    final page = await client.searchTracks('x');

    expect(page.collection, hasLength(1));
    expect(page.collection.first.title, 'A track');
    expect(client.clientId, completion(freshId));
    final apiRequest = requests.last;
    expect(apiRequest.path, '/search/tracks');
    expect(apiRequest.queryParameters['client_id'], freshId);
    expect(apiRequest.queryParameters['q'], 'x');
  });

  test('refreshes once on 401 and retries with the new id', () async {
    var discoveries = 0;
    var apiCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.host == 'player.test') {
        discoveries++;
        return http.Response(
          '<script src="https://assets.test/app.js"></script>',
          200,
        );
      }
      if (request.url.host == 'assets.test') {
        return http.Response(
          'client_id:"${discoveries == 1 ? staleId : freshId}"',
          200,
        );
      }
      apiCalls++;
      if (request.url.queryParameters['client_id'] == staleId) {
        return http.Response('', 401);
      }
      return http.Response(searchBody(), 200);
    });
    final client = SoundCloudClient(
      httpClient: mock,
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );

    final page = await client.searchTracks('x');

    expect(page.collection, hasLength(1));
    expect(discoveries, 2);
    expect(apiCalls, 2);
    expect(await client.clientId, freshId);

    await client.searchTracks('x');
    expect(discoveries, 2, reason: 'the fresh id is reused');
  });

  test('surfaces a 401 when discovery returns the same id', () async {
    var apiCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.host == 'player.test') {
        return http.Response(
          '<script src="https://assets.test/app.js"></script>',
          200,
        );
      }
      if (request.url.host == 'assets.test') {
        return http.Response('client_id:"$staleId"', 200);
      }
      apiCalls++;
      return http.Response('', 401);
    });
    final client = SoundCloudClient(
      httpClient: mock,
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );

    await expectLater(
      client.searchTracks('x'),
      throwsA(isA<SoundCloudException>()
          .having((error) => error.status, 'status', 401)),
    );
    expect(apiCalls, 1);
  });

  test('collapses concurrent refreshes into one discovery', () async {
    var discoveries = 0;
    final mock = MockClient((request) async {
      if (request.url.host == 'player.test') {
        discoveries++;
        return http.Response(
          '<script src="https://assets.test/app.js"></script>',
          200,
        );
      }
      if (request.url.host == 'assets.test') {
        if (discoveries > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return http.Response(
          'client_id:"${discoveries == 1 ? staleId : freshId}"',
          200,
        );
      }
      if (request.url.queryParameters['client_id'] == staleId) {
        return http.Response('', 401);
      }
      return http.Response(searchBody(), 200);
    });
    final client = SoundCloudClient(
      httpClient: mock,
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );

    final results = await Future.wait([
      client.searchTracks('one'),
      client.searchTracks('two'),
    ]);

    expect(results, hasLength(2));
    expect(discoveries, 2, reason: 'one discovery to start, one to refresh');
  });

  test('adds the client id to next_href', () async {
    final mock = MockClient((request) async {
      if (request.url.host == 'player.test') {
        return http.Response(
          '<script src="https://assets.test/app.js"></script>',
          200,
        );
      }
      if (request.url.host == 'assets.test') {
        return http.Response('client_id:"$freshId"', 200);
      }
      if (request.url.queryParameters['offset'] == '1') {
        return http.Response(searchBody(collection: [trackJson(2)]), 200);
      }
      return http.Response(
        searchBody(nextHref: 'https://api.test/search/tracks?q=x&offset=1'),
        200,
      );
    });
    final client = SoundCloudClient(
      httpClient: mock,
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );

    final first = await client.searchTracks('x');
    expect(first.nextHref, isNotNull);
    final second = await client.nextPage(first, Track.fromJson);

    expect(second, isNotNull);
    expect(second!.collection.single.id, 2);
  });

  test('falls through a 404 to the next rendition', () async {
    final requested = <String>[];
    final mock = MockClient((request) async {
      if (request.url.host == 'player.test') {
        return http.Response(
          '<script src="https://assets.test/app.js"></script>',
          200,
        );
      }
      if (request.url.host == 'assets.test') {
        return http.Response('client_id:"$freshId"', 200);
      }
      requested.add(request.url.path);
      if (request.url.path.endsWith('progressive')) {
        return http.Response('{}', 404);
      }
      return http.Response('{"url":"https://cdn.test/audio.m3u8"}', 200);
    });
    final client = SoundCloudClient(
      httpClient: mock,
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );
    final track = Track.fromJson({
      'id': 3,
      'title': 'Two renditions',
      'media': {
        'transcodings': [
          {
            'url': 'https://api.test/media/3/progressive',
            'preset': 'mp3_0_0',
            'format': {'protocol': 'progressive'},
          },
          {
            'url': 'https://api.test/media/3/hls',
            'preset': 'aac_160k',
            'format': {'protocol': 'hls'},
          },
        ],
      },
    });

    final url = await client.resolveStream(track);

    expect(url, 'https://cdn.test/audio.m3u8');
    expect(requested, ['/media/3/progressive', '/media/3/hls']);
  });

  test('throws for a track with no clear transcodings', () async {
    final client = SoundCloudClient(
      httpClient: MockClient((request) async => http.Response('{}', 200)),
      baseUrl: 'https://api.test',
      playerUrl: 'https://player.test/',
      assetPrefix: 'https://assets.test/',
    );
    final track = Track.fromJson({
      'id': 1,
      'title': 'Blocked',
      'streamable': false,
      'media': {'transcodings': []},
    });

    await expectLater(
      client.resolveStream(track),
      throwsA(isA<UnplayableTrackException>()),
    );
  });
}
