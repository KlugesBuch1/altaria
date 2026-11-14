import 'package:material_ui/material_ui.dart';

import 'app_scope.dart';
import 'data/soundcloud_client.dart';
import 'playback/audio_handler.dart';
import 'theme.dart';
import 'training/training_scope.dart';
import 'training/training_store.dart';
import 'ui/home_shell.dart';

class AltariaApp extends StatelessWidget {
  const AltariaApp({
    super.key,
    required this.api,
    required this.player,
    required this.training,
  });

  final SoundCloudClient api;
  final AltariaAudioHandler player;
  final TrainingStore training;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: api,
      player: player,
      child: TrainingScope(
        store: training,
        child: MaterialApp(
          title: 'altaria',
          debugShowCheckedModeBanner: false,
          theme: buildAltariaTheme(),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
