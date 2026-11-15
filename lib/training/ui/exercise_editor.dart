import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import '../models.dart';
import '../repository.dart';
import '../training_scope.dart';
import 'widgets.dart';

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({super.key, this.exercise});

  final Exercise? exercise;

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _cues;
  late MuscleGroup _muscle;
  late Equipment _equipment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _name = TextEditingController(text: exercise?.name ?? '');
    _cues = TextEditingController(text: exercise?.cues ?? '');
    _muscle = exercise?.muscleGroup ?? MuscleGroup.chest;
    _equipment = exercise?.equipment ?? Equipment.barbell;
  }

  @override
  void dispose() {
    _name.dispose();
    _cues.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the movement a name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final store = TrainingScope.of(context);
    try {
      final saved = widget.exercise == null
          ? await store.addCustomExercise(
              name: name,
              muscleGroup: _muscle,
              equipment: _equipment,
              cues: _cues.text,
            )
          : await store.updateCustomExercise(
              widget.exercise!.copyWith(
                name: name,
                muscleGroup: _muscle,
                equipment: _equipment,
                cues: _cues.text,
              ),
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on TrainingRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the movement.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.exercise != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit movement' : 'New movement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const FieldLabel('Name'),
            TextField(
              key: const Key('exercise-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              autofocus: !editing,
              decoration: const InputDecoration(
                hintText: 'e.g. Landmine split squat',
              ),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Muscle group'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final group in MuscleGroup.values)
                  ChoiceChip(
                    label: Text(group.label),
                    selected: _muscle == group,
                    showCheckmark: false,
                    backgroundColor: panel,
                    selectedColor: wine,
                    side: BorderSide(color: _muscle == group ? wine : hairline),
                    labelStyle: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cream),
                    onSelected: (_) => setState(() => _muscle = group),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const FieldLabel('Equipment'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final item in Equipment.values)
                  ChoiceChip(
                    label: Text(item.label),
                    selected: _equipment == item,
                    showCheckmark: false,
                    backgroundColor: panel,
                    selectedColor: wine,
                    side: BorderSide(
                      color: _equipment == item ? wine : hairline,
                    ),
                    labelStyle: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cream),
                    onSelected: (_) => setState(() => _equipment = item),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const FieldLabel('Cues'),
            TextField(
              key: const Key('exercise-cues'),
              controller: _cues,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'One or two things to remember mid-set.',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('save-exercise'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(editing ? 'Save changes' : 'Add movement'),
            ),
            const SizedBox(height: 10),
            Text(
              'Custom movements stay on this device.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
