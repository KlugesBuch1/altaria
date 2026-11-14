import 'package:flutter_test/flutter_test.dart';

import 'package:altaria/data/models.dart';
import 'package:altaria/playback/queue.dart';

Track track(int id) => Track.fromJson({'id': id, 'title': 'Track $id'});

void main() {
  test('starts from the requested index and moves both ways', () {
    final queue = Queue()
      ..replace([track(1), track(2), track(3)], startIndex: 1);

    expect(queue.current?.id, 2);
    expect(queue.hasPrevious, isTrue);
    expect(queue.hasNext, isTrue);
    expect(queue.moveNext()?.id, 3);
    expect(queue.moveNext(), isNull);
    expect(queue.hasNext, isFalse);
    expect(queue.movePrevious()?.id, 2);
    expect(queue.movePrevious()?.id, 1);
    expect(queue.movePrevious(), isNull);
  });

  test('clamps the start index and jumps', () {
    final queue = Queue()..replace([track(1), track(2)], startIndex: 99);
    expect(queue.current?.id, 2);

    queue.jumpTo(-5);
    expect(queue.current?.id, 1);

    queue.jumpTo(99);
    expect(queue.current?.id, 2);
  });

  test('an empty queue has no current track', () {
    final queue = Queue()..replace([]);
    expect(queue.isEmpty, isTrue);
    expect(queue.current, isNull);
    expect(queue.moveNext(), isNull);
    expect(queue.movePrevious(), isNull);
    expect(queue.jumpTo(3), isNull);
  });

  test('clear empties the queue', () {
    final queue = Queue()..replace([track(1)]);
    queue.clear();
    expect(queue.isEmpty, isTrue);
    expect(queue.index, 0);
  });

  test('tracks cannot be mutated through the getter', () {
    final queue = Queue()..replace([track(1)]);
    expect(() => queue.tracks.add(track(2)), throwsUnsupportedError);
  });
}
