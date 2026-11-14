import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:altaria/training/models.dart';
import 'package:altaria/training/ui/mode_switch.dart';
import 'package:altaria/theme.dart';

void main() {
  testWidgets('switches between Listen and Train', (tester) async {
    var mode = AppMode.listen;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAltariaTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AltariaModeSwitch(
                mode: mode,
                onChanged: (next) => setState(() => mode = next),
              );
            },
          ),
        ),
      ),
    );

    expect(mode, AppMode.listen);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);

    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();
    expect(mode, AppMode.train);

    await tester.tap(find.text('Listen'));
    await tester.pumpAndSettle();
    expect(mode, AppMode.listen);
  });
}
