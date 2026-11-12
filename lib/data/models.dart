typedef Json = Map<String, dynamic>;

String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

bool _bool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

List<Json> _objects(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Json>().toList(growable: false);
}

String? artworkAt(String? url, {String size = 't500x500'}) {
  if (url == null || url.isEmpty) return null;
  final match = RegExp(r'-(large|t\d+x\d+|mini|tiny|small|crop|badge)(\.[a-z]+)$')
      .firstMatch(url);
  if (match == null) return url;
  return url.replaceRange(match.start, match.end, '-$size${match.group(2)}');
}

class User {
  const User({
    required this.id,
    required this.username,
    this.permalinkUrl,
    this.avatarUrl,
    this.followersCount,
  });

  factory User.fromJson(Json json) {
    return User(
      id: _int(json['id']) ?? 0,
      username: _string(json['username']) ?? 'Unknown artist',
      permalinkUrl: _string(json['permalink_url']),
      avatarUrl: _string(json['avatar_url']),
      followersCount: _int(json['followers_count']),
    );
  }

  final int id;
  final String username;
  final String? permalinkUrl;
  final String? avatarUrl;
  final int? followersCount;

  String? get imageUrl => artworkAt(avatarUrl, size: 't300x300');
}

class Transcoding {
  const Transcoding({
    required this.url,
    this.preset,
    this.protocol,
    this.mimeType,
    this.snipped = false,
  });

  factory Transcoding.fromJson(Json json) {
    final format = json['format'];
    final formatJson = format is Json ? format : const <String, dynamic>{};
    return Transcoding(
      url: _string(json['url']) ?? '',
      preset: _string(json['preset']),
      protocol: _string(formatJson['protocol']),
      mimeType: _string(formatJson['mime_type']),
      snipped: _bool(json['snipped']),
    );
  }

  final String url;
  final String? preset;
  final String? protocol;
  final String? mimeType;
  final bool snipped;

  bool get isClear => protocol == 'progressive' || protocol == 'hls';
}

class Track {
  const Track({
    required this.id,
    required this.title,
    this.user,
    this.artworkUrl,
    this.permalinkUrl,
    this.duration = Duration.zero,
    this.fullDuration,
    this.streamable = true,
    this.policy,
    this.genre,
    this.playbackCount,
    this.likesCount,
    this.transcodings = const [],
  });

  factory Track.fromJson(Json json) {
    final media = json['media'];
    final mediaJson = media is Json ? media : const <String, dynamic>{};
    final user = json['user'];
    return Track(
      id: _int(json['id']) ?? 0,
      title: _string(json['title']) ?? 'Untitled',
      user: user is Json ? User.fromJson(user) : null,
      artworkUrl: _string(json['artwork_url']),
      permalinkUrl: _string(json['permalink_url']),
      duration: Duration(milliseconds: _int(json['duration']) ?? 0),
      fullDuration: Duration(milliseconds: _int(json['full_duration']) ?? 0),
      streamable: _bool(json['streamable'], fallback: true),
      policy: _string(json['policy']),
      genre: _string(json['genre']),
      playbackCount: _int(json['playback_count']),
      likesCount: _int(json['likes_count']),
      transcodings: _objects(mediaJson['transcodings'])
          .map(Transcoding.fromJson)
          .toList(growable: false),
    );
  }

  final int id;
  final String title;
  final User? user;
  final String? artworkUrl;
  final String? permalinkUrl;
  final Duration duration;
  final Duration? fullDuration;
  final bool streamable;
  final String? policy;
  final String? genre;
  final int? playbackCount;
  final int? likesCount;
  final List<Transcoding> transcodings;

  String get artist => user?.username ?? 'Unknown artist';

  String? get imageUrl =>
      artworkAt(artworkUrl) ?? user?.imageUrl;

  bool get isPreview => policy == 'SNIP';

  List<Transcoding> get playbackOrder {
    final full = transcodings
        .where((item) => item.isClear && !item.snipped)
        .toList(growable: false);
    if (full.isNotEmpty) return _sorted(full);
    return _sorted(
      transcodings.where((item) => item.isClear && item.snipped).toList(),
    );
  }

  bool get isPlayable => streamable && playbackOrder.isNotEmpty;

  static List<Transcoding> _sorted(List<Transcoding> input) {
    int rank(Transcoding item) {
      if (item.protocol == 'progressive') return 0;
      return switch (item.preset) {
        'aac_160k' => 1,
        'aac_96k' => 2,
        'abr_sq' => 9,
        _ => 5,
      };
    }

    return [...input]..sort((a, b) => rank(a).compareTo(rank(b)));
  }
}

class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.user,
    this.artworkUrl,
    this.permalinkUrl,
    this.trackCount = 0,
    this.isAlbum = false,
    this.tracks = const [],
  });

  factory Playlist.fromJson(Json json) {
    final user = json['user'];
    return Playlist(
      id: _int(json['id']) ?? 0,
      title: _string(json['title']) ?? 'Untitled playlist',
      user: user is Json ? User.fromJson(user) : null,
      artworkUrl: _string(json['artwork_url']),
      permalinkUrl: _string(json['permalink_url']),
      trackCount: _int(json['track_count']) ?? 0,
      isAlbum: _bool(json['is_album']),
      tracks: _objects(json['tracks'])
          .map(Track.fromJson)
          .toList(growable: false),
    );
  }

  final int id;
  final String title;
  final User? user;
  final String? artworkUrl;
  final String? permalinkUrl;
  final int trackCount;
  final bool isAlbum;
  final List<Track> tracks;

  String get artist => user?.username ?? 'SoundCloud';

  String? get imageUrl => artworkAt(artworkUrl) ?? user?.imageUrl;
}

class Page<T> {
  const Page({
    required this.collection,
    this.nextHref,
    this.totalResults,
  });

  factory Page.fromJson(Json json, T Function(Json) parse) {
    return Page(
      collection: _objects(json['collection'])
          .map(parse)
          .toList(growable: false),
      nextHref: _string(json['next_href']),
      totalResults: _int(json['total_results']),
    );
  }

  final List<T> collection;
  final String? nextHref;
  final int? totalResults;
}

class ChartEntry {
  const ChartEntry({required this.track, required this.score});

  factory ChartEntry.fromJson(Json json) {
    final track = json['track'];
    return ChartEntry(
      track: Track.fromJson(track is Json ? track : const {}),
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0,
    );
  }

  final Track track;
  final double score;
}

class ChartPage {
  const ChartPage({required this.collection, this.nextHref});

  factory ChartPage.fromJson(Json json) {
    return ChartPage(
      collection: _objects(json['collection'])
          .map(ChartEntry.fromJson)
          .toList(growable: false),
      nextHref: _string(json['next_href']),
    );
  }

  final List<ChartEntry> collection;
  final String? nextHref;
}
