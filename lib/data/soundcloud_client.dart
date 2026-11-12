import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

const browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const _defaultBaseUrl = 'https://api-v2.soundcloud.com';
const _defaultPlayerUrl = 'https://soundcloud.com/';
const _defaultAssetPrefix = 'https://a-v2.sndcdn.com/assets/';
const _requestTimeout = Duration(seconds: 20);

class SoundCloudException implements Exception {
  const SoundCloudException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => 'SoundCloudException: $message';
}

class UnplayableTrackException implements Exception {
  const UnplayableTrackException([this.message = 'This track cannot be played']);

  final String message;

  @override
  String toString() => message;
}

/// Read-only client for the measured api-v2 routes.
///
/// The client id is discovered once and held in memory. A 401 triggers one
/// discovery, and the request is retried once if the id changed. Concurrent
/// refreshes share one discovery.
class SoundCloudClient {
  SoundCloudClient({
    http.Client? httpClient,
    String baseUrl = _defaultBaseUrl,
    this.playerUrl = _defaultPlayerUrl,
    this.assetPrefix = _defaultAssetPrefix,
  })  : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final http.Client _http;
  final bool _ownsHttp;
  final String _baseUrl;
  final String playerUrl;
  final String assetPrefix;

  String? _clientId;
  Future<String>? _discovery;
  Future<String>? _refresh;

  Future<String> get clientId async {
    final held = _clientId;
    if (held != null) return held;
    _discovery ??= _discover().then((id) {
      _clientId = id;
      return id;
    }).whenComplete(() => _discovery = null);
    return _discovery!;
  }

  Future<Track> track(int id) async {
    final json = await _getJson('/tracks/$id');
    return Track.fromJson(json);
  }

  Future<Page<Track>> searchTracks(String query, {int limit = 30}) async {
    final json = await _getJson('/search/tracks', query: {
      'q': query,
      'limit': '$limit',
    });
    return Page.fromJson(json, Track.fromJson);
  }

  Future<Page<User>> searchUsers(String query, {int limit = 30}) async {
    final json = await _getJson('/search/users', query: {
      'q': query,
      'limit': '$limit',
    });
    return Page.fromJson(json, User.fromJson);
  }

  Future<Page<Playlist>> searchPlaylists(String query, {int limit = 30}) async {
    final json = await _getJson('/search/playlists', query: {
      'q': query,
      'limit': '$limit',
    });
    return Page.fromJson(json, Playlist.fromJson);
  }

  Future<Page<Track>> userTracks(int userId, {int limit = 50}) async {
    final json = await _getJson('/users/$userId/tracks', query: {
      'limit': '$limit',
    });
    return Page.fromJson(json, Track.fromJson);
  }

  Future<Playlist> playlist(int id) async {
    final json = await _getJson('/playlists/$id');
    return Playlist.fromJson(json);
  }

  Future<ChartPage> charts({
    String kind = 'trending',
    String genre = 'soundcloud:genres:all-music',
  }) async {
    final json = await _getJson('/charts', query: {
      'kind': kind,
      'genre': genre,
      'limit': '50',
    });
    return ChartPage.fromJson(json);
  }

  Future<Page<T>?> nextPage<T>(
    Page<T> page,
    T Function(Json) parse,
  ) async {
    final href = page.nextHref;
    if (href == null) return null;
    final parsed = Uri.parse(href);
    final uri =
        parsed.hasScheme ? parsed : Uri.parse(_baseUrl).resolveUri(parsed);
    final json = await _getJsonUri(uri);
    return Page.fromJson(json, parse);
  }

  /// Resolves the first playable transcoding immediately before playback.
  ///
  /// A 404 on one rendition moves to the next one in priority order.
  Future<String> resolveStream(Track track) async {
    final candidates = track.playbackOrder;
    if (candidates.isEmpty) {
      throw const UnplayableTrackException();
    }
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final json = await _getJsonUri(Uri.parse(candidate.url));
        final url = json['url'];
        if (url is String && url.isNotEmpty) return url;
      } on SoundCloudException catch (error) {
        lastError = error;
        if (error.status == 404) continue;
        rethrow;
      }
    }
    throw UnplayableTrackException(
      lastError == null
          ? 'This track cannot be played'
          : 'This track cannot be played (${lastError.toString()})',
    );
  }

  Future<Json> _getJson(
    String path, {
    Map<String, String> query = const {},
  }) {
    return _requestJson((id) {
      final uri = Uri.parse('$_baseUrl$path');
      return _withClientId(
        uri.replace(queryParameters: {...uri.queryParameters, ...query}),
        id,
      );
    });
  }

  Future<Json> _getJsonUri(Uri uri) {
    return _requestJson((id) => _withClientId(uri, id));
  }

  Future<Json> _requestJson(Uri Function(String) build) async {
    var id = await clientId;
    var response = await _get(build(id));
    if (response.statusCode == 401) {
      final fresh = await _refreshClientId(id);
      if (fresh == null) {
        throw const SoundCloudException(
          'SoundCloud rejected the request',
          status: 401,
        );
      }
      response = await _get(build(fresh));
    }
    if (response.statusCode != 200) {
      throw SoundCloudException(
        'SoundCloud returned HTTP ${response.statusCode}',
        status: response.statusCode,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Json) {
      throw const SoundCloudException('Unexpected response from SoundCloud');
    }
    return decoded;
  }

  Future<http.Response> _get(Uri uri) {
    return _http
        .get(uri, headers: {'User-Agent': browserUserAgent})
        .timeout(_requestTimeout);
  }

  Future<String?> _refreshClientId(String stale) async {
    final current = _clientId;
    if (current != null && current != stale) return current;
    _refresh ??= _discover().then((id) {
      _clientId = id;
      return id;
    }).whenComplete(() => _refresh = null);
    final fresh = await _refresh!;
    return fresh == stale ? null : fresh;
  }

  Future<String> _discover() async {
    final page = await _get(Uri.parse(playerUrl));
    if (page.statusCode != 200) {
      throw SoundCloudException(
        'Could not load the SoundCloud player page',
        status: page.statusCode,
      );
    }
    final html = utf8.decode(page.bodyBytes);
    final assets = RegExp('$assetPrefix[^"\\s]+\\.js')
        .allMatches(html)
        .map((match) => match.group(0)!)
        .toSet();
    if (assets.isEmpty) {
      throw const SoundCloudException(
        'The SoundCloud player page referenced no assets',
      );
    }
    for (final asset in assets.take(12)) {
      final response = await _get(Uri.parse(asset));
      if (response.statusCode != 200) continue;
      final match = RegExp(r'client_id:"([A-Za-z0-9]{32})"')
          .firstMatch(utf8.decode(response.bodyBytes));
      if (match != null) return match.group(1)!;
    }
    throw const SoundCloudException(
      'No client id in the SoundCloud player assets',
    );
  }

  Uri _withClientId(Uri uri, String id) {
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'client_id': id},
    );
  }

  void close() {
    if (_ownsHttp) _http.close();
  }
}
