import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/models/external_species_observation_model.dart';

class ExternalBiodiversityReferencesSection extends StatelessWidget {
  const ExternalBiodiversityReferencesSection({
    super.key,
    required this.referencesFuture,
  });

  final Future<ExternalSpeciesReferenceResult> referencesFuture;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'External Biodiversity References'),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<ExternalSpeciesReferenceResult>(
          future: referencesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SilvamangCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Loading iNaturalist references...')),
                  ],
                ),
              );
            }

            final result = snapshot.data;
            if (snapshot.hasError || result == null || !result.hasObservations) {
              return SilvamangCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.public_off_rounded,
                      color: AppColors.warningOrange,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        result?.message ??
                            'External biodiversity references are unavailable.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.public_rounded,
                        color: AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Supporting iNaturalist observations for ${result.speciesName}.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _summaryText(result),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...result.observations.take(4).map(
                    (observation) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ExternalObservationTile(
                        observation: observation,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _summaryText(ExternalSpeciesReferenceResult result) {
    final parts = <String>[
      '${result.observationCount} cached reference${result.observationCount == 1 ? '' : 's'}',
      '${result.photosCount} photo${result.photosCount == 1 ? '' : 's'}',
    ];

    final lastSyncedAt = result.lastSyncedAt;
    if (lastSyncedAt != null) {
      parts.add('last synced ${DateFormat('MMM d, yyyy').format(lastSyncedAt)}');
    }

    return parts.join(' | ');
  }
}

class _ExternalObservationTile extends StatelessWidget {
  const _ExternalObservationTile({required this.observation});

  final ExternalSpeciesObservationModel observation;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      onTap: observation.sourceUrl == null
          ? null
          : () => _openReference(context, observation.sourceUrl!),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ObservationPhoto(photoUrl: observation.photoUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    observation.location ?? 'Location not provided',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _metadataText(observation),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                  if (observation.qualityGrade?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _cleanLabel(observation.qualityGrade!),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDarkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: AppColors.primaryDarkGreen,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _metadataText(ExternalSpeciesObservationModel observation) {
    final parts = <String>[
      if (observation.observer?.isNotEmpty == true)
        'Observer: ${observation.observer}',
      if (observation.observedDate != null)
        DateFormat('MMM d, yyyy').format(observation.observedDate!),
      if (observation.hasCoordinates)
        '${observation.latitude!.toStringAsFixed(4)}, ${observation.longitude!.toStringAsFixed(4)}',
    ];

    return parts.isEmpty ? 'Observation details unavailable' : parts.join(' | ');
  }
}

class _ObservationPhoto extends StatelessWidget {
  const _ObservationPhoto({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported_rounded,
          color: AppColors.mutedText,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 72,
          height: 72,
          color: AppColors.white,
          child: const Icon(
            Icons.image_not_supported_rounded,
            color: AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}

Future<void> _openReference(BuildContext context, String url) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open external reference.')),
    );
  }
}

String _cleanLabel(String value) {
  final label = value.replaceAll('_', ' ').trim();
  if (label.isEmpty) {
    return 'Not available';
  }

  return label
      .split(' ')
      .map((word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
