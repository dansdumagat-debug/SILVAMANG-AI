import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/map/data/services/parent_fallback_tile_provider.dart';

class TestImage extends ImageProvider<TestImage> {
  const TestImage(this.image);
  final ui.Image? image;
  @override
  Future<TestImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(TestImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        image == null
            ? Future<ImageInfo>.error(StateError('missing tile'))
            : Future.value(ImageInfo(image: image!.clone())),
      );
}

class TestTiles extends TileProvider {
  TestTiles(this.source);
  final ui.Image source;
  final requested = <TileCoordinates>[];
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requested.add(coordinates);
    return TestImage(coordinates.z == 18 ? source : null);
  }
}

void main() {
  test(
    'parent crop selects correct geographic quadrant across zoom levels',
    () {
      expect(
        parentTileCrop(TileCoordinates(11, 13, 20), 19, 256, 256),
        const Rect.fromLTWH(128, 128, 128, 128),
      );
      expect(
        parentTileCrop(TileCoordinates(11, 13, 20), 18, 256, 256),
        const Rect.fromLTWH(192, 64, 64, 64),
      );
    },
  );
  testWidgets('missing close-up tiles use the correctly cropped parent', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 256, 256),
        Paint()..color = const Color(0xFF00AA00),
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(256, 256);
      picture.dispose();
      final delegate = TestTiles(source);
      final provider = ParentFallbackTileProvider(delegate);
      final stream = provider
          .getImage(
            TileCoordinates(11, 13, 20),
            TileLayer(urlTemplate: 'https://example.test/{z}/{x}/{y}'),
          )
          .resolve(ImageConfiguration.empty);
      final done = Completer<ImageInfo>();
      final listener = ImageStreamListener(
        (info, _) => done.complete(info),
        onError: (Object error, StackTrace? stack) =>
            done.completeError(error, stack),
      );
      stream.addListener(listener);
      final result = await done.future;
      expect(delegate.requested.map((c) => c.z), [20, 19, 18]);
      expect(delegate.requested.last.x, 2);
      expect(delegate.requested.last.y, 3);
      expect(result.image.width, 256);
      final pixels = await result.image.toByteData();
      expect(pixels!.getUint8(1), 170);
      stream.removeListener(listener);
      result.dispose();
      source.dispose();
    });
  });
}
