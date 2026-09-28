import 'transect_observation_model.dart';
import 'transect_point_model.dart';

class TransectContributionModel {
  const TransectContributionModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.distanceM,
    required this.points,
    required this.observations,
    required this.recordedAt,
  });

  final String id;
  final String? userId;
  final String userName;
  final double distanceM;
  final List<TransectPointModel> points;
  final List<TransectObservationModel> observations;
  final DateTime recordedAt;

  factory TransectContributionModel.fromJson(Map<String, dynamic> json) =>
      TransectContributionModel(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString(),
        userName: json['user_name']?.toString() ?? 'Mobile User',
        distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
        points: (json['points'] as List? ?? [])
            .whereType<Map>()
            .map(
              (item) =>
                  TransectPointModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
        observations: (json['observations'] as List? ?? [])
            .whereType<Map>()
            .map(
              (item) => TransectObservationModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
        recordedAt:
            DateTime.tryParse(json['recorded_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'distance_m': distanceM,
    'points': points.map((point) => point.toJson()).toList(),
    'observations': observations
        .map((observation) => observation.toJson())
        .toList(),
    'recorded_at': recordedAt.toIso8601String(),
  };
}
