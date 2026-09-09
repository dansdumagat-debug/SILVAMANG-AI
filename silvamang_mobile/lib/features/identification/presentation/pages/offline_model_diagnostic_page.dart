import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/services/offline_prediction_service.dart';

class OfflineModelDiagnosticPage extends StatefulWidget {
  const OfflineModelDiagnosticPage({super.key});

  @override
  State<OfflineModelDiagnosticPage> createState() =>
      _OfflineModelDiagnosticPageState();
}

class _OfflineModelDiagnosticPageState
    extends State<OfflineModelDiagnosticPage> {
  final OfflinePredictionService _service = OfflinePredictionService();

  OfflineModelDiagnosticResult? _result;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_runDiagnostic);
  }

  Future<void> _runDiagnostic() async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.checkOfflineModel();
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = OfflineModelDiagnosticResult(
          platformSupported: false,
          classOrderLoaded: false,
          classCount: 0,
          singleModelAssetLoaded: false,
          pairedModelAssetLoaded: false,
          pairedDataAssetLoaded: false,
          selectedModelAsset: '',
          selectedModelFileSize: 0,
          sessionCreationAttempted: true,
          sessionCreationSucceeded: false,
          dummyInferenceSucceeded: false,
          failureReason: 'session_creation_failed',
          technicalDetail: kDebugMode ? error.toString() : null,
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.profile,
        ),
        title: const Text('Offline Model Diagnostic'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          const SectionHeader(title: 'Offline Model Diagnostic'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SilvamangBadge(
                      label: result == null
                          ? 'Not tested'
                          : result.isReady
                          ? 'Passed'
                          : 'Failed',
                      type: result?.isReady == true
                          ? SilvamangBadgeType.success
                          : SilvamangBadgeType.warning,
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  result?.isReady == true
                      ? 'Offline model is ready.'
                      : 'Offline model is not ready.',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  result?.failureReason == null
                      ? 'This checks Android support, assets, ONNX session creation, and dummy inference.'
                      : 'Reason: ${result!.failureReason}',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Run Diagnostic',
                  icon: Icons.science_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _runDiagnostic,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              children: [
                _DiagnosticRow(
                  label: 'Platform supported',
                  value: _yesNo(result?.platformSupported),
                ),
                _DiagnosticRow(
                  label: 'class_order.json',
                  value: _yesNo(result?.classOrderLoaded),
                ),
                _DiagnosticRow(
                  label: 'Class count',
                  value: result?.classCount.toString() ?? 'Not tested',
                ),
                _DiagnosticRow(
                  label: 'Single ONNX asset',
                  value: _yesNo(result?.singleModelAssetLoaded),
                ),
                _DiagnosticRow(
                  label: 'Paired ONNX asset',
                  value: _yesNo(result?.pairedModelAssetLoaded),
                ),
                _DiagnosticRow(
                  label: 'Paired data asset',
                  value: _yesNo(result?.pairedDataAssetLoaded),
                ),
                _DiagnosticRow(
                  label: 'Selected model',
                  value: result?.selectedModelAsset.isEmpty == false
                      ? result!.selectedModelAsset
                      : 'Not selected',
                ),
                _DiagnosticRow(
                  label: 'Model size',
                  value: result == null
                      ? 'Not tested'
                      : '${result.selectedModelFileSize} bytes',
                ),
                _DiagnosticRow(
                  label: 'Session creation',
                  value: _yesNo(result?.sessionCreationSucceeded),
                ),
                _DiagnosticRow(
                  label: 'Input names',
                  value: result?.inputNames.isEmpty == false
                      ? result!.inputNames.join(', ')
                      : 'Not available',
                ),
                _DiagnosticRow(
                  label: 'Output names',
                  value: result?.outputNames.isEmpty == false
                      ? result!.outputNames.join(', ')
                      : 'Not available',
                ),
                _DiagnosticRow(
                  label: 'Dummy inference',
                  value: _yesNo(result?.dummyInferenceSucceeded),
                ),
              ],
            ),
          ),
          if (kDebugMode && result?.technicalDetail != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SilvamangCard(
              child: Text(
                result!.technicalDetail!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warningOrange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

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
            width: 132,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(child: Text(value, style: AppTextStyles.labelLarge)),
        ],
      ),
    );
  }
}

String _yesNo(bool? value) {
  if (value == null) {
    return 'Not tested';
  }
  return value ? 'Passed' : 'Failed';
}
