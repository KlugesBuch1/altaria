import '../calculators.dart';
import '../models.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String formatTrainingDuration(int seconds) {
  final clamped = seconds < 0 ? 0 : seconds;
  final hours = clamped ~/ 3600;
  final minutes = (clamped % 3600) ~/ 60;
  final rest = clamped % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

String formatRest(int seconds) => formatTrainingDuration(seconds);

String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String formatMonthYear(DateTime date) =>
    '${_months[date.month - 1]} ${date.year}';

String formatWeekdayDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} '
    '${_months[date.month - 1]}';

String formatRelativeDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return formatDate(date);
}

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String formatCompactNumber(num value) {
  if (value >= 1000000) {
    final compact = value / 1000000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}m';
  }
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}k';
  }
  return value.round().toString();
}

String formatSetLoad(WorkoutSet set, WeightUnit unit) {
  final hasWeight = set.weightKg > 0;
  final hasReps = set.reps > 0;
  if (hasWeight && hasReps) {
    return '${weightValue(set.weightKg, unit)} ${unit.storage} × ${set.reps}';
  }
  if (hasReps) return '${set.reps} reps';
  if (set.durationSeconds > 0) {
    final time = formatTrainingDuration(set.durationSeconds);
    if (set.distanceMeters > 0) {
      return '$time · ${set.distanceMeters.toStringAsFixed(0)} m';
    }
    return time;
  }
  if (set.distanceMeters > 0) {
    return '${set.distanceMeters.toStringAsFixed(0)} m';
  }
  return '—';
}

String formatRpe(double? rpe) =>
    rpe == null ? '' : 'RPE ${rpe.toStringAsFixed(rpe % 1 == 0 ? 0 : 1)}';

String formatRestClock(int seconds) {
  final clamped = seconds < 0 ? 0 : seconds;
  final minutes = clamped ~/ 60;
  final rest = clamped % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
