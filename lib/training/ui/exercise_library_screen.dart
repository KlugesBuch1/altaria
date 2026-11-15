import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../models.dart';
import '../repository.dart';
import '../training_scope.dart';
import 'exercise_editor.dart';
import 'widgets.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, this.picker = false});

  final bool picker;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  String _query = '';
  MuscleGroup? _muscle;
  Equipment? _equipment;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Exercise> _filtered(List<Exercise> all) {
    final query = _query.trim().toLowerCase();
    return all
        .where((exercise) {
          if (_muscle != null && exercise.muscleGroup != _muscle) {
            return false;
          }
          if (_equipment != null && exercise.equipment != _equipment) {
            return false;
          }
          if (query.isEmpty) return true;
          return exercise.name.toLowerCase().contains(query) ||
              exercise.cues.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _create() async {
    final added = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseEditorScreen()),
    );
    if (!mounted || added == null) return;
    if (widget.picker) {
      Navigator.of(context).pop(added);
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${added.name} added.')));
  }

  Future<void> _edit(Exercise exercise) async {
    await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseEditorScreen(exercise: exercise),
      ),
    );
  }

  Future<void> _delete(Exercise exercise) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${exercise.name}?',
      message:
          'It disappears from the library. Past workouts keep the movement.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await TrainingScope.of(context).deleteCustomExercise(exercise.id);
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _select(Exercise exercise) {
    if (widget.picker) {
      Navigator.of(context).pop(exercise);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panelHigh,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    TrainingTag(label: exercise.muscleGroup.label),
                    TrainingTag(label: exercise.equipment.label, color: ember),
                    if (exercise.custom)
                      const TrainingTag(label: 'Custom', color: rose),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  exercise.cues.isEmpty
                      ? 'No cues yet. Edit the movement to add one.'
                      : exercise.cues,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: muted, height: 1.45),
                ),
                if (exercise.custom) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _edit(exercise);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _delete(exercise);
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final items = _filtered(store.exercises);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.picker ? 'Choose movement' : 'Movements'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-exercise'),
        onPressed: _create,
        backgroundColor: wine,
        foregroundColor: cream,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New movement'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: TextField(
                key: const Key('exercise-search'),
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search 200+ movements',
                  prefixIcon: const Icon(Icons.search_rounded, color: frost),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, color: muted),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _muscle == null,
                    onTap: () => setState(() => _muscle = null),
                  ),
                  for (final group in MuscleGroup.values) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: group.label,
                      selected: _muscle == group,
                      onTap: () => setState(
                        () => _muscle = _muscle == group ? null : group,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  Text(
                    '${items.length} ${items.length == 1 ? 'movement' : 'movements'}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: muted, letterSpacing: 1.1),
                  ),
                  const Spacer(),
                  PopupMenuButton<Equipment>(
                    color: panelHigh,
                    tooltip: 'Filter by equipment',
                    onSelected: (value) => setState(
                      () => _equipment = _equipment == value ? null : value,
                    ),
                    itemBuilder: (context) => [
                      for (final equipment in Equipment.values)
                        PopupMenuItem(
                          value: equipment,
                          child: Row(
                            children: [
                              if (_equipment == equipment)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: ember,
                                  ),
                                ),
                              Text(equipment.label),
                            ],
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: hairline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: frost,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _equipment?.label ?? 'Equipment',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cream),
                          ),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_equipment != null)
                    IconButton(
                      tooltip: 'Clear equipment filter',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _equipment = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyPanel(
                      icon: Icons.search_off_rounded,
                      title: 'No matching movements',
                      message: 'Change the search or filters, or make a custom movement.',
                      action: FilledButton.tonal(
                        onPressed: () {
                          _search.clear();
                          setState(() {
                            _query = '';
                            _muscle = null;
                            _equipment = null;
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final exercise = items[index];
                        return _ExerciseRow(
                          key: Key('exercise-${exercise.id}'),
                          exercise: exercise,
                          picking: widget.picker,
                          onTap: () => _select(exercise),
                          onEdit: exercise.custom
                              ? () => _edit(exercise)
                              : null,
                          onDelete: exercise.custom
                              ? () => _delete(exercise)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: panel,
      selectedColor: wine,
      side: BorderSide(color: selected ? wine : hairline),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: selected ? cream : muted,
        fontWeight: FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    super.key,
    required this.exercise,
    required this.picking,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Exercise exercise;
  final bool picking;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TrainingCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cream,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (exercise.custom) ...[
                      const SizedBox(width: 6),
                      const TrainingTag(label: 'Custom', color: rose),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.muscleGroup.label} · ${exercise.equipment.label}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (exercise.cues.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.cues,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (picking)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.add_rounded, color: ember),
            )
          else if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              color: panelHigh,
              icon: const Icon(Icons.more_vert_rounded, color: muted),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right_rounded, color: muted),
            ),
        ],
      ),
    );
  }
}
