import 'package:material_ui/material_ui.dart';

import 'training_store.dart';

class TrainingScope extends InheritedNotifier<TrainingStore> {
  const TrainingScope({
    super.key,
    required TrainingStore store,
    required super.child,
  }) : super(notifier: store);

  static TrainingStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TrainingScope>();
    assert(scope != null, 'TrainingScope is missing above this widget');
    return scope!.notifier!;
  }

  static TrainingStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TrainingScope>()
        ?.notifier;
  }
}
