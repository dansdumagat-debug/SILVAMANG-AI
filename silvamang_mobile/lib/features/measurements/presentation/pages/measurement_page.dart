import '../../../../shared/widgets/ecological_survey_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../../shared/widgets/structural_measurement_fields.dart';
import '../../../identification/presentation/controllers/identification_controller.dart';

class MeasurementPage extends ConsumerStatefulWidget {
  const MeasurementPage({super.key});
  @override
  ConsumerState<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends ConsumerState<MeasurementPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final result = ref.read(identificationControllerProvider).result;
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Measurements'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
          children: [
            EcologicalSurveyFields(
              initial: result.surveyDetails,
              onChanged: (values) => ref
                  .read(identificationControllerProvider.notifier)
                  .setSurveyDetails(values),
            ),
            TextFormField(
              initialValue: result.plotNo,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Plot No (optional)',
              ),
              onChanged: (value) => ref
                  .read(identificationControllerProvider.notifier)
                  .setPlotNumber(value),
            ),
            SilvamangCard(
              child: StructuralMeasurementFields(
                initial: {
                  'height_m': result.heightM.isFinite && result.heightM > 0
                      ? result.heightM
                      : null,
                  'gbh_cm': result.gbhCm,
                  'canopy_1_m': result.canopy1M,
                  'canopy_2_m': result.canopy2M,
                },
                onChanged: (values) => ref
                    .read(identificationControllerProvider.notifier)
                    .setStructuralMeasurements(values),
              ),
            ),
            const SizedBox(height: 16),
            SilvamangButton(
              text: 'Continue to Location Validation',
              icon: Icons.location_on_outlined,
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                context.pushNamed(RouteNames.locationValidation);
              },
            ),
          ],
        ),
      ),
    );
  }
}
