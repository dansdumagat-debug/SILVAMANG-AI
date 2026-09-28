import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../transects/presentation/controllers/transects_controller.dart';
import '../../data/models/captured_plant_part_image.dart';
import '../controllers/capture_controller.dart';

class CaptureGuidePage extends ConsumerStatefulWidget {
  const CaptureGuidePage({super.key, this.transectLocalId});

  final String? transectLocalId;

  @override
  ConsumerState<CaptureGuidePage> createState() => _CaptureGuidePageState();
}

class _CaptureGuidePageState extends ConsumerState<CaptureGuidePage> {
  List<_SpeciesChoice> _speciesChoices = const [];
  _SpeciesChoice? _chosenSpecies;
  String _typedSpecies = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final captureState = ref.read(captureControllerProvider);
      if (!captureState.hasImageFor('canopy') &&
          !captureState.hasImageFor('full_tree')) {
        return;
      }
      final captureController = ref.read(captureControllerProvider.notifier);
      captureController.removeImage('canopy');
      captureController.removeImage('full_tree');
      captureController.clearMessages();
    });
    _loadSpeciesChoices();
  }

  Future<void> _loadSpeciesChoices() async {
    final choices = <String, _SpeciesChoice>{};
    for (final path in [
      'assets/data/mangrove_education.json',
      'assets/data/panel_mangrove_education.json',
    ]) {
      try {
        final decoded = jsonDecode(await rootBundle.loadString(path));
        if (decoded is! List) continue;
        for (final item in decoded.whereType<Map>()) {
          final choice = _SpeciesChoice(
            scientificName:
                (item['display_name'] ?? item['scientific_name'] ?? '')
                    .toString()
                    .replaceAll('_', ' ')
                    .trim(),
            commonName: (item['common_name'] ?? '').toString().trim(),
          );
          if (choice.scientificName.isNotEmpty) {
            choices[choice.scientificName.toLowerCase()] = choice;
          }
        }
      } catch (_) {
        // Free-text species entry remains available without the local catalog.
      }
    }
    if (mounted) {
      setState(
        () =>
            _speciesChoices = choices.values.toList()
              ..sort((a, b) => a.scientificName.compareTo(b.scientificName)),
      );
    }
  }

  void _continueWithSpecies() {
    final captureState = ref.read(captureControllerProvider);
    final speciesName = _chosenSpecies?.scientificName ?? _typedSpecies.trim();
    if (speciesName.isNotEmpty) {
      context.pushNamed(
        RouteNames.manualSpeciesMeasurement,
        queryParameters: {
          if (widget.transectLocalId != null)
            'transectId': widget.transectLocalId!,
        },
        extra: <String, String>{
          'scientificName': speciesName,
          'commonName': _chosenSpecies?.commonName ?? '',
        },
      );
      return;
    }
    if (captureState.capturedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please capture or select at least one mangrove image.',
          ),
        ),
      );
      return;
    }
    context.pushNamed(
      RouteNames.identificationResult,
      queryParameters: {
        if (widget.transectLocalId != null)
          'transectId': widget.transectLocalId!,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(captureControllerProvider);
    final transectId = widget.transectLocalId;
    final transect = transectId == null
        ? null
        : ref
              .watch(transectsControllerProvider)
              .records
              .where((item) => item.localId == transectId)
              .firstOrNull;
    final captureController = ref.read(captureControllerProvider.notifier);
    final capturedCount = _plantParts
        .where((part) => captureState.hasImageFor(part.key))
        .length;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Capture Mangrove'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          if (transectId != null) ...[
            SilvamangCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.route_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Scanning for ${transect?.transectName ?? transectId}',
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'Capture clear images of key plant parts for better identification.',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Captured $capturedCount of ${_plantParts.length} plant parts',
                    style: AppTextStyles.labelLarge,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: LinearProgressIndicator(
                    value: capturedCount / _plantParts.length,
                    color: AppColors.primaryGreen,
                    backgroundColor: AppColors.borderSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Photos are optional when you enter a species. AI identification needs at least one photo.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      color: AppColors.primaryDarkGreen,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Species (optional)',
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose a species or type its name to skip photo identification. Leave blank to identify from your photos.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Autocomplete<_SpeciesChoice>(
                  displayStringForOption: (choice) => choice.label,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return const Iterable<_SpeciesChoice>.empty();
                    }
                    return _speciesChoices.where(
                      (choice) => choice.label.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (choice) => setState(() {
                    _chosenSpecies = choice;
                    _typedSpecies = choice.scientificName;
                  }),
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmit) => TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Species name',
                          hintText: 'Search or type a species name',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) => setState(() {
                          _chosenSpecies = null;
                          _typedSpecies = value;
                        }),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangButton(
            text: _typedSpecies.trim().isEmpty
                ? 'Continue to Identification'
                : 'Continue to Measurements',
            icon: _typedSpecies.trim().isEmpty
                ? Icons.image_search_rounded
                : Icons.straighten_rounded,
            onPressed: _continueWithSpecies,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _typedSpecies.trim().isEmpty
                ? 'Add a photo below to identify this mangrove.'
                : 'Next: enter height and canopy width, then save with a location.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (captureState.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                captureState.errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.dangerRed,
                ),
              ),
            ),
          ],
          if (captureState.successMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                captureState.successMessage!,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final part in _plantParts) ...[
            _PlantPartCaptureCard(
              part: part,
              image: captureState.getImageFor(part.key),
              isPicking: captureState.isPicking,
              onCamera: () => captureController.pickFromCamera(part.key),
              onGallery: () => captureController.pickFromGallery(part.key),
              onRemove: () => captureController.removeImage(part.key),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          const SectionHeader(title: 'Capture Tip'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Use natural lighting and avoid blurry photos for better identification.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesChoice {
  const _SpeciesChoice({
    required this.scientificName,
    required this.commonName,
  });

  final String scientificName;
  final String commonName;
  String get label =>
      commonName.isEmpty ? scientificName : '$scientificName - $commonName';
}

const _plantParts = [
  _PlantPartConfig(
    key: 'leaves',
    title: 'Leaves',
    instruction: 'Capture clear leaf shape, color, and arrangement.',
    icon: Icons.eco_rounded,
  ),
  _PlantPartConfig(
    key: 'bark',
    title: 'Bark',
    instruction: 'Capture trunk or bark texture.',
    icon: Icons.forest_rounded,
  ),
  _PlantPartConfig(
    key: 'roots',
    title: 'Roots',
    instruction: 'Capture roots, prop roots, or root structure.',
    icon: Icons.grass_rounded,
  ),
  _PlantPartConfig(
    key: 'flowers',
    title: 'Flowers',
    instruction: 'Capture flowers or reproductive parts if visible.',
    icon: Icons.local_florist_rounded,
  ),
];

class _PlantPartConfig {
  const _PlantPartConfig({
    required this.key,
    required this.title,
    required this.instruction,
    required this.icon,
  });

  final String key;
  final String title;
  final String instruction;
  final IconData icon;
}

class _PlantPartCaptureCard extends StatefulWidget {
  const _PlantPartCaptureCard({
    required this.part,
    required this.image,
    required this.isPicking,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final _PlantPartConfig part;
  final CapturedPlantPartImage? image;
  final bool isPicking;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  State<_PlantPartCaptureCard> createState() => _PlantPartCaptureCardState();
}

class _PlantPartCaptureCardState extends State<_PlantPartCaptureCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final part = widget.part;
    final image = widget.image;
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Semantics(
              button: true,
              expanded: _expanded,
              label: '${part.title} photo options',
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.softGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      part.icon,
                      color: AppColors.primaryDarkGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(part.title, style: AppTextStyles.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(part.instruction, style: AppTextStyles.bodySmall),
                        if (image != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Photo added',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.md),
            if (image == null)
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: AppColors.primaryGreen,
                  size: 42,
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  image.previewBytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (image != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      image.source == 'camera' ? 'Camera' : 'Gallery',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(image.fileName, style: AppTextStyles.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SilvamangButton(
                    text: 'Capture',
                    icon: Icons.camera_alt_rounded,
                    fullWidth: false,
                    isLoading: widget.isPicking,
                    onPressed: widget.isPicking ? null : widget.onCamera,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SilvamangButton(
                    text: 'Gallery',
                    icon: Icons.photo_library_rounded,
                    type: SilvamangButtonType.outline,
                    fullWidth: false,
                    isLoading: widget.isPicking,
                    onPressed: widget.isPicking ? null : widget.onGallery,
                  ),
                ),
              ],
            ),
            if (image != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
