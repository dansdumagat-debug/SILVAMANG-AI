import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiIdentificationConfig {
  const AiIdentificationConfig._();

  static const double defaultConfidenceThreshold = 0.70;

  static double get confidenceThreshold {
    const dartDefinedValue = String.fromEnvironment('AI_CONFIDENCE_THRESHOLD');
    final configuredValue = dartDefinedValue.trim().isNotEmpty
        ? dartDefinedValue
        : dotenv.isInitialized
        ? dotenv.maybeGet('AI_CONFIDENCE_THRESHOLD')
        : null;

    return parseConfidenceThreshold(configuredValue);
  }

  static double parseConfidenceThreshold(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 1) {
      return defaultConfidenceThreshold;
    }

    return parsed;
  }
}
