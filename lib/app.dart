import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'ui/home_shell.dart';

class AltariaApp extends StatelessWidget {
  const AltariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'altaria',
      debugShowCheckedModeBanner: false,
      theme: buildAltariaTheme(),
      home: const HomeShell(),
    );
  }
}
