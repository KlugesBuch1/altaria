import 'dart:collection';

import '../data/models.dart';

/// The play order for one session. It never wraps.
class Queue {
  List<Track> _tracks = const [];
  int _index = 0;

  UnmodifiableListView<Track> get tracks => UnmodifiableListView(_tracks);

  int get index => _index;

  bool get isEmpty => _tracks.isEmpty;

  bool get hasNext => _index + 1 < _tracks.length;

  bool get hasPrevious => _index > 0;

  Track? get current => isEmpty ? null : _tracks[_index];

  Track? get next => hasNext ? _tracks[_index + 1] : null;

  Track? get previous => hasPrevious ? _tracks[_index - 1] : null;

  void replace(List<Track> tracks, {int startIndex = 0}) {
    _tracks = List<Track>.unmodifiable(tracks);
    _index = tracks.isEmpty ? 0 : startIndex.clamp(0, tracks.length - 1);
  }

  Track? moveNext() {
    if (!hasNext) return null;
    _index++;
    return current;
  }

  Track? movePrevious() {
    if (!hasPrevious) return null;
    _index--;
    return current;
  }

  Track? jumpTo(int index) {
    if (isEmpty) return null;
    _index = index.clamp(0, _tracks.length - 1);
    return current;
  }

  void clear() {
    _tracks = const [];
    _index = 0;
  }
}
