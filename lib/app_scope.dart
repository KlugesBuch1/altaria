import 'package:material_ui/material_ui.dart';

import 'data/soundcloud_client.dart';
import 'playback/audio_handler.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.player,
    required super.child,
  });

  final SoundCloudClient api;
  final AltariaAudioHandler player;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api || player != oldWidget.player;
}
