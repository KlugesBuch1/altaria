// Renders the launcher icon and the adaptive-icon foreground from the same
// a monogram the app's identity is built on. Run from the repository root:
//
//   flutter test tool/render_brand_assets_test.dart
//
// This rewrites assets/icon.png and assets/icon_foreground.png. Run
// `dart run flutter_launcher_icons` afterwards to fan them out to Android
// and iOS.
//
// Note: flutter_launcher_icons 0.14.4 rewrites
// ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS to "AppIcon"
// in ios/Runner.xcodeproj. Restore it to YES after generating.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:altaria/theme.dart';
import 'package:altaria/ui/logo.dart';

Future<void> _write(RenderRepaintBoundary boundary, String path) async {
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) {
    throw StateError('Could not encode $path');
  }
  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  testWidgets('renders the launcher icon and adaptive foreground', (
    tester,
  ) async {
    final loader = FontLoader('Jost')
      ..addFont(rootBundle.load('assets/fonts/Jost-Bold.ttf'));
    await loader.load();

    tester.view.physicalSize = const Size(2048, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const legacyKey = Key('legacy-icon');
    const adaptiveKey = Key('adaptive-icon');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 2048,
          height: 1024,
          child: Row(
            children: [
              RepaintBoundary(
                key: legacyKey,
                child: SizedBox(
                  width: 1024,
                  height: 1024,
                  child: ColoredBox(
                    color: wine,
                    child: Center(
                      child: AltariaMonogram(size: 1024, background: null),
                    ),
                  ),
                ),
              ),
              // Android insets the adaptive foreground by 16 percent, so the
              // transparent source carries its own breathing room.
              RepaintBoundary(
                key: adaptiveKey,
                child: SizedBox(
                  width: 1024,
                  height: 1024,
                  child: Center(
                    child: AltariaMonogram(size: 1024, background: null),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final legacy = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(legacyKey),
    );
    final adaptive = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(adaptiveKey),
    );

    // toImage rasterises on the engine thread, so the fake-async test zone has
    // to step aside for it.
    await tester.runAsync(() async {
      await _write(legacy, 'assets/icon.png');
      await _write(adaptive, 'assets/icon_foreground.png');
    });
  });
}
