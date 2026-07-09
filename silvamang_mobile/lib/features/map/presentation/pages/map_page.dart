import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_card.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Monitoring Map')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: const [
                Expanded(child: _Segment(label: 'Map', selected: true)),
                Expanded(child: _Segment(label: 'Satellite')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 330,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.softBlue, AppColors.softGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              ),
              child: Stack(
                children: const [
                  Positioned(top: 58, left: 44, child: _MapPin(label: '01')),
                  Positioned(top: 118, right: 54, child: _MapPin(label: '02')),
                  Positioned(bottom: 78, left: 86, child: _MapPin(label: '03')),
                  Positioned(
                    bottom: 46,
                    right: 96,
                    child: _MapPin(label: '04'),
                  ),
                  Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.dangerRed,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Observation Points',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    Text('14 Sites', style: AppTextStyles.labelLarge),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _SiteRow(
                  site: 'Site 01',
                  species: 'Rhizophora mucronata',
                  time: '2h ago',
                ),
                const _SiteRow(
                  site: 'Site 02',
                  species: 'Avicennia marina',
                  time: '5h ago',
                ),
                const _SiteRow(
                  site: 'Site 03',
                  species: 'Bruguiera gymnorrhiza',
                  time: '1d ago',
                ),
                const _SiteRow(
                  site: 'Site 04',
                  species: 'Sonneratia alba',
                  time: '2d ago',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Map Preview',
            subtitle:
                'Static placeholder only. Real map SDK and GPS come later.',
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryDarkGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelLarge.copyWith(
          color: selected ? AppColors.white : AppColors.primaryDarkGreen,
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.primaryDarkGreen,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
            ),
          ),
        ),
        const Icon(
          Icons.arrow_drop_down_rounded,
          color: AppColors.primaryDarkGreen,
          size: 28,
        ),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    required this.site,
    required this.species,
    required this.time,
  });

  final String site;
  final String species;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, color: AppColors.primaryGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('$site - $species', style: AppTextStyles.bodyMedium),
          ),
          Text(time, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
