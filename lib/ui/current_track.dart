import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../playback/audio_handler.dart';

class CurrentTrackBuilder extends StatelessWidget {
  const CurrentTrackBuilder({
    super.key,
    required this.handler,
    required this.builder,
  });

  final AltariaAudioHandler handler;
  final Widget Function(BuildContext context, int? currentTrackId) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      initialData: handler.mediaItem.value,
      builder: (context, snapshot) {
        final id = int.tryParse(snapshot.data?.id ?? '');
        return builder(context, id);
      },
    );
  }
}
