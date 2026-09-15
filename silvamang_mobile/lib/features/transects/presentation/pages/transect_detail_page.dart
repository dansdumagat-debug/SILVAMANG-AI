import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/local_image_preview.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/models/transect_observation_model.dart';
import '../../data/models/transect_point_model.dart';
import '../../data/models/transect_record_model.dart';
import '../controllers/transects_controller.dart';
import '../widgets/transect_field_map.dart';

class TransectDetailPage extends ConsumerStatefulWidget {
  const TransectDetailPage({super.key, required this.transectId});

  final String transectId;

  @override
  ConsumerState<TransectDetailPage> createState() => _TransectDetailPageState();
}

class _TransectDetailPageState extends ConsumerState<TransectDetailPage> {
  final _mapController = MapController();
  TransectMapLayer _mapLayer = TransectMapLayer.satellite;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRecord);
  }

  Future<void> _loadRecord() async {
    final notifier = ref.read(transectsControllerProvider.notifier);
    final current = ref.read(transectsControllerProvider);
    if (current.records.isEmpty) {
      await notifier.load();
    }
    await notifier.select(widget.transectId);
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitPath());
  }

  void _fitPath() {
    final record = ref.read(transectsControllerProvider).selectedRecord;
    if (!mounted || record == null || record.points.isEmpty) {
      return;
    }
    final coordinates = record.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coordinates,
          padding: const EdgeInsets.all(52),
          maxZoom: 18,
        ),
      );
    } catch (_) {
      // The map can still be mounting on slow devices; its initial center works.
    }
  }

  Future<void> _delete(TransectRecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transect?'),
        content: Text(
          record.isSynced
              ? 'This removes the transect from this device and the server. Attached scan records are kept.'
              : 'This removes the locally saved transect. Attached scan records are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final deleted = await ref
        .read(transectsControllerProvider.notifier)
        .delete(record);
    if (deleted && mounted) {
      context.goNamed(RouteNames.transects);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transectsControllerProvider);
    final record = state.selectedRecord;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.transects,
        ),
        title: const Text('Transect Details'),
        actions: [
          if (record != null && !record.isSynced)
            IconButton(
              tooltip: 'Synchronize',
              onPressed: state.isSyncing
                  ? null
                  : () => ref
                        .read(transectsControllerProvider.notifier)
                        .syncPending(),
              icon: const Icon(Icons.sync_rounded),
            ),
          if (record != null)
            IconButton(
              tooltip: 'Delete transect',
              onPressed: () => _delete(record),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : record == null
          ? _MissingRecord(
              message: state.errorMessage ?? 'Transect record was not found.',
              onRetry: _loadRecord,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                112,
              ),
              children: [
                _RecordHeader(record: record),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Notice(
                    message: state.errorMessage!,
                    color: AppColors.warningOrange,
                    icon: Icons.info_outline_rounded,
                  ),
                ],
                if (state.successMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Notice(
                    message: state.successMessage!,
                    color: AppColors.successGreen,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Transect Map',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    SegmentedButton<TransectMapLayer>(
                      segments: const [
                        ButtonSegment(
                          value: TransectMapLayer.satellite,
                          icon: Icon(Icons.satellite_alt_rounded),
                          tooltip: 'Satellite',
                        ),
                        ButtonSegment(
                          value: TransectMapLayer.street,
                          icon: Icon(Icons.map_outlined),
                          tooltip: 'Street map',
                        ),
                      ],
                      selected: {_mapLayer},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _mapLayer = selection.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 390,
                  child: TransectFieldMap(
                    mapController: _mapController,
                    points: record.points,
                    observations: record.observations,
                    isOnline: state.isOnline,
                    layer: _mapLayer,
                    lineColor: record.isGpsTracking
                        ? AppColors.primaryGreen
                        : const Color(0xFF2472B8),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _fitPath,
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: const Text('Fit path'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _MetricGrid(record: record),
                const SizedBox(height: AppSpacing.xl),
                Text('Field Information', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SilvamangCard(
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Researcher',
                        value: record.researcherName ?? 'Not specified',
                      ),
                      _DetailRow(
                        label: 'Recorded',
                        value: DateFormat(
                          'MMM d, yyyy  h:mm a',
                        ).format(record.recordedAt.toLocal()),
                      ),
                      _DetailRow(
                        label: 'Mode',
                        value: record.isGpsTracking
                            ? 'GPS walk tracking'
                            : 'Manual map points',
                      ),
                      _DetailRow(
                        label: 'Location',
                        value: record.locationName ?? 'Not specified',
                      ),
                      if (record.description?.trim().isNotEmpty == true)
                        _DetailRow(
                          label: 'Notes',
                          value: record.description!,
                          last: true,
                        )
                      else
                        const _DetailRow(
                          label: 'Notes',
                          value: 'None',
                          last: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Species Distribution', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _SpeciesDistribution(record: record),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Attached Observations',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    Text(
                      '${record.observations.length}',
                      style: AppTextStyles.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (record.observations.isEmpty)
                  const _EmptySection(
                    icon: Icons.eco_outlined,
                    text: 'No scan records are attached to this transect.',
                  )
                else
                  ...record.observations.map(
                    (observation) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ObservationCard(observation: observation),
                    ),
                  ),
                if (record.pendingObservationReferences.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Notice(
                    message:
                        '${record.pendingObservationReferences.length} observation link(s) will be resolved after their scan records sync.',
                    color: AppColors.warningOrange,
                    icon: Icons.link_off_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('GPS Point Log', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _PointLog(points: record.points),
                const SizedBox(height: AppSpacing.xl),
                const _ScientificNote(),
              ],
            ),
    );
  }
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({required this.record});

  final TransectRecordModel record;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.syncStatus) {
      TransectRecordModel.syncSynced => AppColors.successGreen,
      TransectRecordModel.syncFailed => AppColors.dangerRed,
      _ => AppColors.warningOrange,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.displayCode, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 4),
                  Text(record.transectName, style: AppTextStyles.titleLarge),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                switch (record.syncStatus) {
                  TransectRecordModel.syncSynced => 'Synced',
                  TransectRecordModel.syncFailed => 'Sync failed',
                  _ => 'Pending sync',
                },
                style: AppTextStyles.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (record.locationName?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(record.locationName!, style: AppTextStyles.bodyMedium),
        ],
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.record});

  final TransectRecordModel record;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _MetricTile(
              width: width,
              label: 'Distance',
              value: _distance(record.totalDistanceM),
              icon: Icons.straighten_rounded,
            ),
            _MetricTile(
              width: width,
              label: 'Direction',
              value: record.bearingDegrees == null
                  ? 'N/A'
                  : '${record.directionLabel} ${record.bearingDegrees!.toStringAsFixed(0)} deg',
              icon: Icons.navigation_rounded,
            ),
            _MetricTile(
              width: width,
              label: 'GPS Points',
              value: '${record.points.length}',
              icon: Icons.timeline_rounded,
            ),
            _MetricTile(
              width: width,
              label: 'Observations',
              value: '${record.observations.length}',
              icon: Icons.eco_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primaryGreen),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium,
          ),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _SpeciesDistribution extends StatelessWidget {
  const _SpeciesDistribution({required this.record});

  final TransectRecordModel record;

  @override
  Widget build(BuildContext context) {
    final entries = record.speciesDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const _EmptySection(
        icon: Icons.bar_chart_rounded,
        text: 'Species counts appear after scan records are attached.',
      );
    }
    final largest = entries.first.value;
    return SilvamangCard(
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _SpeciesRow(entry: entries[index], largest: largest),
            if (index < entries.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({required this.entry, required this.largest});

  final MapEntry<String, int> entry;
  final int largest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelLarge,
              ),
            ),
            Text('${entry.value}', style: AppTextStyles.labelLarge),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: entry.value / largest,
            minHeight: 6,
            backgroundColor: AppColors.softGreen,
          ),
        ),
      ],
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.observation});

  final TransectObservationModel observation;

  @override
  Widget build(BuildContext context) {
    final path = observation.imagePath?.trim();
    final networkImage =
        path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
    return SilvamangCard(
      onTap: observation.serverId == null
          ? null
          : () => context.pushNamed(
              RouteNames.recordDetail,
              pathParameters: {'id': observation.serverId!},
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (networkImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: path,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.square(
                  dimension: 76,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => LocalImagePreview(
                  imagePath: path,
                  width: 76,
                  height: 76,
                  borderRadius: 8,
                ),
              ),
            )
          else
            LocalImagePreview(
              imagePath: path,
              width: 76,
              height: 76,
              borderRadius: 8,
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation.scientificName.trim().isEmpty
                      ? 'Unidentified species'
                      : observation.scientificName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                if (observation.commonName.trim().isNotEmpty)
                  Text(
                    observation.commonName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    if (observation.heightM != null)
                      _TinyFact(
                        icon: Icons.height_rounded,
                        text: '${observation.heightM!.toStringAsFixed(1)} m',
                      ),
                    if (observation.canopyWidthM != null)
                      _TinyFact(
                        icon: Icons.open_in_full_rounded,
                        text:
                            '${observation.canopyWidthM!.toStringAsFixed(1)} m',
                      ),
                    if (observation.hasCoordinates)
                      const _TinyFact(
                        icon: Icons.location_on_outlined,
                        text: 'GPS',
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  observation.recordCode.isEmpty
                      ? observation.reference
                      : observation.recordCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (observation.serverId != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
        ],
      ),
    );
  }
}

class _TinyFact extends StatelessWidget {
  const _TinyFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primaryGreen),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _PointLog extends StatelessWidget {
  const _PointLog({required this.points});

  final List<TransectPointModel> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptySection(
        icon: Icons.location_off_outlined,
        text: 'No coordinates were recorded.',
      );
    }
    return SilvamangCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(
          Icons.list_alt_rounded,
          color: AppColors.primaryDarkGreen,
        ),
        title: Text('${points.length} recorded point(s)'),
        subtitle: Text(
          'Start ${points.first.latitude.toStringAsFixed(5)}, ${points.first.longitude.toStringAsFixed(5)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          const Divider(height: 1),
          for (var index = 0; index < points.length; index++)
            _PointRow(index: index, point: points[index]),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.index, required this.point});

  final int index;
  final TransectPointModel point;

  @override
  Widget build(BuildContext context) {
    final label = index == 0
        ? 'Start'
        : index == 1
        ? 'Point 2'
        : 'Point ${index + 1}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
              ),
            ),
          ),
          if (point.accuracyM != null)
            Text(
              '${point.accuracyM!.toStringAsFixed(0)} m',
              style: AppTextStyles.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _MissingRecord extends StatelessWidget {
  const _MissingRecord({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.screenPadding),
      child: SilvamangCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to open transect', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            SilvamangButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScientificNote extends StatelessWidget {
  const _ScientificNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF2472B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This digital record supports field documentation. It does not replace required scientific transect protocols, calibrated instruments, or expert review.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _distance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
  return '${meters.toStringAsFixed(meters >= 100 ? 0 : 1)} m';
}
