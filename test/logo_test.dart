import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:altaria/theme.dart';
import 'package:altaria/ui/logo.dart';
import 'package:altaria/ui/wordmark.dart';

void main() {
  testWidgets('the wordmark carries the name and the rose full stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAltariaTheme(),
        home: const Scaffold(body: Wordmark()),
      ),
    );

    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.text('altaria.', findRichText: true), findsOneWidget);
  });

  testWidgets('the icon is the a monogram and can carry a label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AltariaMonogram(size: 48, semanticLabel: 'altaria icon'),
          ),
        ),
      ),
    );

    expect(find.text('a'), findsOneWidget);
    expect(tester.getSize(find.byType(AltariaMonogram)), const Size(48, 48));
    expect(find.bySemanticsLabel('altaria icon'), findsOneWidget);
    semantics.dispose();
  });
}
