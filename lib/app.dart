import 'package:material_ui/material_ui.dart';

import 'app_scope.dart';
import 'data/soundcloud_client.dart';
import 'playback/audio_handler.dart';
import 'theme.dart';
import 'ui/home_shell.dart';

class AltariaApp extends StatelessWidget {
  const AltariaApp({super.key, required this.api, required this.player});

  final SoundCloudClient api;
  final AltariaAudioHandler player;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: api,
      player: player,
      child: MaterialApp(
        title: 'altaria',
        debugShowCheckedModeBanner: false,
        theme: buildAltariaTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
