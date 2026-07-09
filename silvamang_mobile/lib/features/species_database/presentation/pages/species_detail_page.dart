import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../controllers/species_controller.dart';

class SpeciesDetailPage extends ConsumerStatefulWidget {
  const SpeciesDetailPage({super.key, required this.speciesId});

  final String speciesId;

  @override
  ConsumerState<SpeciesDetailPage> createState() => _SpeciesDetailPageState();
}

class _SpeciesDetailPageState extends ConsumerState<SpeciesDetailPage> {
  int get _speciesId => int.tryParse(widget.speciesId) ?? 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(speciesControllerProvider.notifier)
          .loadSpeciesById(_speciesId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(speciesControllerProvider);
    final species = state.selectedSpecies;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Species Detail')),
      body: state.isLoading
          ? const LoadingView(message: 'Loading species details...')
          : state.errorMessage != null
          ? Padding(
              padding: const EdgeInsets.all(AppConstants.screenPadding),
              child: SilvamangCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load species',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(state.errorMessage!, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    SilvamangButton(
                      text: 'Retry',
                      icon: Icons.refresh_rounded,
                      onPressed: () => ref
                          .read(speciesControllerProvider.notifier)
                          .loadSpeciesById(_speciesId),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                AppConstants.screenPadding,
                112,
              ),
              children: [
                SilvamangCard(
                  padding: EdgeInsets.zero,
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.softGreen, AppColors.softBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardRadius,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.forest_rounded,
                        color: AppColors.primaryDarkGreen,
                        size: 82,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  species?.scientificName.isNotEmpty == true
                      ? species!.scientificName
                      : 'Unknown species',
                  style: AppTextStyles.displayLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  species?.commonName.isNotEmpty == true
                      ? species!.commonName
                      : 'Common name not specified',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SilvamangBadge(
                    label: species?.nativeStatus.isNotEmpty == true
                        ? species!.nativeStatus
                        : 'Native status not specified',
                    type: SilvamangBadgeType.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StaticTab(label: 'Overview', selected: true),
                    _StaticTab(label: 'Characteristics'),
                    _StaticTab(label: 'Ecology'),
                    _StaticTab(label: 'Images'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Overview'),
                const SizedBox(height: AppSpacing.md),
                SilvamangCard(
                  child: Column(
                    children: [
                      _InfoRow(label: 'Family', value: species?.family ?? ''),
                      _InfoRow(label: 'Genus', value: species?.genus ?? ''),
                      _InfoRow(label: 'Habitat', value: species?.habitat ?? ''),
                      _InfoRow(
                        label: 'Distribution',
                        value: species?.distributionNotes ?? '',
                      ),
                      _InfoRow(
                        label: 'Ecological Role',
                        value: species?.ecologicalRole ?? '',
                      ),
                      _InfoRow(
                        label: 'Identification',
                        value: species?.identificationNotes ?? '',
                      ),
                      _InfoRow(
                        label: 'Conservation',
                        value: species?.conservationStatus ?? '',
                      ),
                      _InfoRow(
                        label: 'Native Status',
                        value: species?.nativeStatus ?? '',
                      ),
                      _InfoRow(
                        label: 'Max Height',
                        value: species?.maxHeightM == null
                            ? ''
                            : '${species!.maxHeightM!.toStringAsFixed(1)} m',
                      ),
                      _InfoRow(label: 'Status', value: species?.status ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SilvamangCard(
                  child: Text(
                    species?.description.isNotEmpty == true
                        ? species!.description
                        : 'Description is not available yet.',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SilvamangButton(
                  text: 'Add Observation',
                  icon: Icons.add_a_photo_rounded,
                  onPressed: () => context.goNamed(RouteNames.captureGuide),
                ),
              ],
            ),
    );
  }
}

class _StaticTab extends StatelessWidget {
  const _StaticTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: selected ? AppColors.primaryDarkGreen : AppColors.white,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.primaryDarkGreen,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(child: Text(value, style: AppTextStyles.labelLarge)),
        ],
      ),
    );
  }
}
