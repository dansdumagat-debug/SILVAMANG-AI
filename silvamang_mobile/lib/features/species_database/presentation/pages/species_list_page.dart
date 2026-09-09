import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../controllers/species_controller.dart';

class SpeciesListPage extends ConsumerStatefulWidget {
  const SpeciesListPage({super.key});

  @override
  ConsumerState<SpeciesListPage> createState() => _SpeciesListPageState();
}

class _SpeciesListPageState extends ConsumerState<SpeciesListPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(speciesControllerProvider.notifier).loadSpecies(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(speciesControllerProvider);
    final speciesList = state.species;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Biodiversity Database'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          TextField(
            controller: _searchController,
            onSubmitted: (value) => ref
                .read(speciesControllerProvider.notifier)
                .searchSpecies(value),
            decoration: InputDecoration(
              hintText: 'Search species...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => ref
                    .read(speciesControllerProvider.notifier)
                    .searchSpecies(_searchController.text),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SpeciesChip(label: 'All Species', selected: true),
              _SpeciesChip(label: 'Native'),
              _SpeciesChip(label: 'Endemic'),
              _SpeciesChip(label: 'Threatened'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.isLoading)
            const SizedBox(
              height: 260,
              child: LoadingView(message: 'Loading species database...'),
            )
          else if (state.errorMessage != null)
            SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        .loadSpecies(),
                  ),
                ],
              ),
            )
          else if (speciesList.isEmpty)
            const EmptyState(
              title: 'No species found',
              message: 'Species information will appear here.',
              icon: Icons.menu_book_rounded,
            )
          else
            ...speciesList.map(
              (species) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SilvamangCard(
                  onTap: () => context.pushNamed(
                    RouteNames.speciesDetail,
                    pathParameters: {'id': species.id.toString()},
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.forest_rounded,
                          color: AppColors.primaryDarkGreen,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              species.scientificName,
                              style: AppTextStyles.titleMedium,
                            ),
                            Text(
                              species.commonName,
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              species.family,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SilvamangBadge(
                              label: species.conservationStatus.isEmpty
                                  ? 'Not specified'
                                  : species.conservationStatus,
                              type: _badgeTypeFor(species.conservationStatus),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

SilvamangBadgeType _badgeTypeFor(String status) {
  final value = status.toLowerCase();
  if (value.contains('threat') ||
      value.contains('vulnerable') ||
      value.contains('endangered')) {
    return SilvamangBadgeType.warning;
  }
  if (value.contains('inactive')) {
    return SilvamangBadgeType.neutral;
  }
  return SilvamangBadgeType.success;
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({required this.label, this.selected = false});

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
