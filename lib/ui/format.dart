String formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

String formatCount(int? count) {
  if (count == null) return '';
  if (count >= 1000000) {
    final value = count / 1000000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
  }
  if (count >= 1000) {
    final value = count / 1000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}K';
  }
  return '$count';
}
