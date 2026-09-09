import '../models/location_validation_model.dart';
import '../models/measurement_model.dart';
import '../models/prediction_model.dart';
import '../models/scan_record_model.dart';
import '../models/species_model.dart';

class MockSilvamangData {
  const MockSilvamangData._();

  static const species = [
    SpeciesModel(
      id: 1,
      scientificName: 'Rhizophora apiculata',
      commonName: 'Bakauan lalaki',
      family: 'Rhizophoraceae',
      habitat: 'Intertidal mangrove forests',
      conservationStatus: 'Least Concern',
    ),
    SpeciesModel(
      id: 2,
      scientificName: 'Rhizophora mucronata',
      commonName: 'Bakauan babae',
      family: 'Rhizophoraceae',
      habitat: 'River mouths and protected coasts',
      conservationStatus: 'Least Concern',
    ),
    SpeciesModel(
      id: 3,
      scientificName: 'Bruguiera gymnorrhiza',
      commonName: 'Pototan',
      family: 'Rhizophoraceae',
      habitat: 'Muddy mangrove swamps',
      conservationStatus: 'Least Concern',
    ),
  ];

  static final scanRecord = ScanRecordModel(
    id: 'demo-scan-record',
    recordCode: 'SIL-0001',
    topScientificName: 'Rhizophora mucronata',
    topCommonName: 'Bakauan babae',
    confidence: 92.4,
    validationStatus: 'match',
    locationName: 'Not available',
    createdAt: DateTime.now(),
  );

  static const predictions = [
    PredictionModel(
      rank: 1,
      scientificName: 'Rhizophora mucronata',
      commonName: 'Bakauan babae',
      confidence: 92.4,
    ),
    PredictionModel(
      rank: 2,
      scientificName: 'Rhizophora apiculata',
      commonName: 'Bakauan lalaki',
      confidence: 84.1,
    ),
  ];

  static const measurement = MeasurementModel(
    heightM: 6.8,
    canopyWidthM: 4.2,
    method: 'AI assisted estimate',
    confidence: 88.6,
  );

  static const locationValidation = LocationValidationModel(
    result: 'pending',
    message: 'Location coordinates are not available for this mock record.',
  );
}
