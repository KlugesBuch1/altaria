import 'package:flutter_test/flutter_test.dart';

import 'package:altaria/ui/format.dart';

void main() {
  test('formats minutes and hours', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(minutes: 5, seconds: 3)), '5:03');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('formats counts compactly', () {
    expect(formatCount(null), '');
    expect(formatCount(999), '999');
    expect(formatCount(1500), '1.5K');
    expect(formatCount(12000), '12K');
    expect(formatCount(2500000), '2.5M');
  });
}
