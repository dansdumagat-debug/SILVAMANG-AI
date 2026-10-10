import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:silvamang_mobile/features/map/data/services/offline_map_cache_service_native.dart';
import 'package:silvamang_mobile/features/map/data/services/parent_fallback_tile_provider.dart';
import 'package:silvamang_mobile/features/map/presentation/widgets/confirm_delete_offline_maps.dart';

void main() {
  test('offline maps never expire and can read legacy downloaded tiles', () {
    final provider =
        OfflineMapCacheService().tileProvider(isOnline: false)
            as ParentFallbackTileProvider;
    final cache = provider.delegate as FMTCTileProvider;
    expect(cache.cachedValidDuration, Duration.zero);
    expect(cache.loadingStrategy, BrowseLoadingStrategy.cacheOnly);
    expect(
      cache.stores[OfflineMapCacheService.storeName],
      BrowseStoreStrategy.read,
    );
    expect(provider.legacyCacheFallback, isTrue);
    provider.dispose();
  });
  for (final choice in ['Keep maps', 'Delete maps', 'dismiss']) {
    testWidgets('deletion confirmation: $choice', (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await confirmDeleteOfflineMaps(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(confirmed, isNull);
      if (choice == 'dismiss') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(choice));
      }
      await tester.pumpAndSettle();
      expect(confirmed, choice == 'Delete maps');
    });
  }
}
