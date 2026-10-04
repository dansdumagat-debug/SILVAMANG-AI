import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// Keeps geographic alignment when a provider has no tile at the requested level.
class ParentFallbackTileProvider extends TileProvider {
  ParentFallbackTileProvider(this.delegate, {this.legacyCacheFallback = false})
    : super(headers: delegate.headers);
  final TileProvider delegate;
  final bool legacyCacheFallback;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _ParentTileImage(delegate, coordinates, options, legacyCacheFallback);

  @override
  void dispose() => delegate.dispose();
}

Rect parentTileCrop(
  TileCoordinates child,
  int parentZoom,
  int width,
  int height,
) {
  final factor = 1 << (child.z - parentZoom);
  return Rect.fromLTWH(
    (child.x % factor) * width / factor,
    (child.y % factor) * height / factor,
    width / factor,
    height / factor,
  );
}

class _ParentTileImage extends ImageProvider<_ParentTileImage> {
  const _ParentTileImage(
    this.delegate,
    this.coordinates,
    this.options,
    this.legacyCacheFallback,
  );
  final bool legacyCacheFallback;
  final TileProvider delegate;
  final TileCoordinates coordinates;
  final TileLayer options;

  @override
  Future<_ParentTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _ParentTileImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_load());

  Future<ImageInfo> _load() async {
    Object? lastError;
    for (
      var zoom = coordinates.z;
      zoom >= math.max(0, coordinates.z - 6);
      zoom--
    ) {
      final shift = coordinates.z - zoom;
      final parent = TileCoordinates(
        coordinates.x >> shift,
        coordinates.y >> shift,
        zoom,
      );
      ui.Image? source;
      try {
        try {
          source = await _resolve(delegate.getImage(parent, options));
        } catch (_) {
          if (!legacyCacheFallback) rethrow;
          source = await _resolve(
            delegate.getImage(
              parent,
              TileLayer(
                urlTemplate: options.urlTemplate?.replaceAll(
                  '?blankTile=false',
                  '',
                ),
                userAgentPackageName: 'com.silvamang.mobile',
              ),
            ),
          );
        }
        if (shift == 0) return ImageInfo(image: source);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          source,
          parentTileCrop(coordinates, zoom, source.width, source.height),
          const Rect.fromLTWH(0, 0, 256, 256),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(256, 256);
        picture.dispose();
        source.dispose();
        return ImageInfo(image: image);
      } catch (error) {
        source?.dispose();
        lastError = error;
      }
    }
    throw StateError('No available map tiles: $lastError');
  }

  Future<ui.Image> _resolve(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
      },
      onError: (Object error, StackTrace? stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      stream.removeListener(listener);
    }
  }
}
