import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../calculators.dart';
import '../models.dart';
import '../training_scope.dart';
import 'format.dart';
import 'widgets.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _calendar = false;
  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _open(Workout workout) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(workoutId: workout.id),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final history = store.history;
    final unit = store.settings.unit;
    final monthWorkouts = history
        .where((workout) => _inMonth(workout, _month))
        .toList(growable: false);
    final shown = _selectedDay == null
        ? monthWorkouts
        : monthWorkouts
              .where(
                (workout) => _sameDay(
                  (workout.finishedAt ?? workout.startedAt).toLocal(),
                  _selectedDay!,
                ),
              )
              .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TrainingHeader(
          eyebrow: 'Train',
          title: 'History',
          subtitle: history.isEmpty
              ? 'Every session lives only on this device.'
              : '${history.length} ${history.length == 1 ? 'session' : 'sessions'} logged. All local.',
          trailing: _ViewToggle(
            calendar: _calendar,
            onList: () => setState(() => _calendar = false),
            onCalendar: () => setState(() => _calendar = true),
          ),
        ),
        if (history.isEmpty) ...[
          const SizedBox(height: 22),
          const EmptyPanel(
            icon: Icons.history_rounded,
            title: 'No sessions logged',
            message:
                'Finish a workout and it lands here with its duration, volume '
                'and set count. Start one from the Workout tab.',
          ),
        ] else ...[
          const SizedBox(height: 18),
          _SummaryStrip(history: history, unit: unit),
          const SizedBox(height: 18),
          if (_calendar)
            _CalendarCard(
              month: _month,
              workouts: monthWorkouts,
              selectedDay: _selectedDay,
              onPrevious: _previousMonth,
              onNext: _nextMonth,
              onSelect: (day) => setState(
                () => _selectedDay =
                    _selectedDay != null && _sameDay(day, _selectedDay!)
                    ? null
                    : day,
              ),
            )
          else
            for (var index = 0; index < history.length; index++) ...[
              if (index == 0 ||
                  !_sameMonth(
                    (history[index - 1].finishedAt ??
                            history[index - 1].startedAt)
                        .toLocal(),
                    (history[index].finishedAt ?? history[index].startedAt)
                        .toLocal(),
                  ))
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 18, bottom: 8),
                  child: TrainingSectionTitle(
                    title: formatMonthYear(
                      (history[index].finishedAt ?? history[index].startedAt)
                          .toLocal(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryRow(
                  workout: history[index],
                  unit: unit,
                  onTap: () => _open(history[index]),
                ),
              ),
            ],
          if (_calendar) ...[
            const SizedBox(height: 14),
            TrainingSectionTitle(
              title: _selectedDay == null
                  ? 'This month'
                  : formatDate(_selectedDay!),
              action: _selectedDay == null
                  ? null
                  : TextButton(
                      onPressed: () => setState(() => _selectedDay = null),
                      child: const Text('Clear day'),
                    ),
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _selectedDay == null
                      ? 'No sessions in this month.'
                      : 'Rest day. No sessions logged.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted),
                ),
              )
            else
              for (final workout in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryRow(
                    workout: workout,
                    unit: unit,
                    onTap: () => _open(workout),
                  ),
                ),
          ],
        ],
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.calendar,
    required this.onList,
    required this.onCalendar,
  });

  final bool calendar;
  final VoidCallback onList;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hairline),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewButton(
            key: const Key('history-list'),
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            selected: !calendar,
            onTap: onList,
          ),
          _ViewButton(
            key: const Key('history-calendar'),
            icon: Icons.calendar_month_rounded,
            tooltip: 'Calendar view',
            selected: calendar,
            onTap: onCalendar,
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? wine : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 19, color: selected ? cream : muted),
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.history, required this.unit});

  final List<Workout> history;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final totalVolume = history.fold<double>(
      0,
      (total, workout) => total + workout.totalVolumeKg,
    );
    final totalSets = history.fold<int>(
      0,
      (total, workout) => total + workout.setCount,
    );
    final totalTime = history.fold<int>(
      0,
      (total, workout) => total + workout.durationSeconds,
    );
    return TrainingCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: StatCell(
              value: '${history.length}',
              label: 'Sessions',
              accent: frost,
            ),
          ),
          Expanded(
            child: StatCell(value: '$totalSets', label: 'Sets', accent: ember),
          ),
          Expanded(
            child: StatCell(
              value: formatVolume(totalVolume, unit),
              label: 'Volume',
            ),
          ),
          Expanded(
            child: StatCell(
              value: formatTrainingDuration(totalTime),
              label: 'Time',
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.workout,
    required this.unit,
    required this.onTap,
  });

  final Workout workout;
  final WeightUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = (workout.finishedAt ?? workout.startedAt).toLocal();
    return TrainingCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hairline),
            ),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: cream, height: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  formatMonthYear(date).split(' ').first.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: muted, fontSize: 8, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: cream, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '${workout.setCount} sets · '
                  '${formatVolume(workout.totalVolumeKg, unit)} · '
                  '${formatTrainingDuration(workout.durationSeconds)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.workouts,
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final List<Workout> workouts;
  final DateTime? selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final first = DateTime(month.year, month.month);
    final leading = first.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var index = 0; index < leading; index++) null,
      for (var day = 1; day <= days; day++)
        DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final today = DateTime.now();
    return TrainingCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('calendar-prev'),
                tooltip: 'Previous month',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  formatMonthYear(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: cream),
                ),
              ),
              IconButton(
                key: const Key('calendar-next'),
                tooltip: 'Next month',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final day in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.92,
            children: [
              for (final day in cells)
                if (day == null)
                  const SizedBox.shrink()
                else
                  _CalendarDay(
                    key: Key('calendar-day-${day.day}'),
                    day: day,
                    today: _sameDay(day, today),
                    selected:
                        selectedDay != null && _sameDay(day, selectedDay!),
                    count: workouts
                        .where(
                          (workout) => _sameDay(
                            (workout.finishedAt ?? workout.startedAt).toLocal(),
                            day,
                          ),
                        )
                        .length,
                    onTap: () => onSelect(day),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    super.key,
    required this.day,
    required this.today,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final bool today;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: selected
            ? wine
            : today
            ? panelHigh
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? ember
                : today
                ? frost.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: selected ? cream : muted),
                ),
                const SizedBox(height: 3),
                if (count > 0)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: ember,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool _inMonth(Workout workout, DateTime month) {
  final date = (workout.finishedAt ?? workout.startedAt).toLocal();
  return date.year == month.year && date.month == month.month;
}
