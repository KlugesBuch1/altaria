import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/soundcloud_client.dart';
import 'playback/audio_handler.dart';
import 'theme.dart';
import 'training/database.dart';
import 'training/notifications.dart';
import 'training/repository.dart';
import 'training/training_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final trainingDatabase = await TrainingDatabase.open();
  final repository = TrainingRepository(trainingDatabase);
  await repository.ensureSeed();
  final notifier = RestNotificationService();
  await notifier.initialize();
  final training = await TrainingStore.load(
    repository: repository,
    notifier: notifier,
  );

  final api = SoundCloudClient();
  final player = await AudioService.init(
    builder: () => AltariaAudioHandler(api: api),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.klugesbuch.altaria.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Playing from altaria',
      notificationColor: panel,
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      preloadArtwork: true,
      artDownscaleWidth: 800,
      artDownscaleHeight: 800,
    ),
  );
  runApp(AltariaApp(api: api, player: player, training: training));
}
