<?php

namespace App\Services;

use App\Models\SpeciesDistribution;

class LocationValidationService
{
    private const DEFAULT_RADIUS_KM = 10.0;
    private const NEARBY_THRESHOLD_KM = 25.0;

    /**
     * @return array{result: string, distance_to_known_distribution_km: float|null, message: string}
     */
    public function validateSpeciesLocation(?int $speciesId, ?float $latitude, ?float $longitude): array
    {
        if (! $speciesId) {
            return [
                'result' => 'unknown',
                'distance_to_known_distribution_km' => null,
                'message' => 'Species is not linked to this scan record.',
            ];
        }

        if ($latitude === null || $longitude === null) {
            return [
                'result' => 'unknown',
                'distance_to_known_distribution_km' => null,
                'message' => 'Location coordinates are missing.',
            ];
        }

        $distributions = SpeciesDistribution::query()
            ->where('species_id', $speciesId)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get();

        if ($distributions->isEmpty()) {
            return [
                'result' => 'unknown',
                'distance_to_known_distribution_km' => null,
                'message' => 'No verified distribution data is available for this species.',
            ];
        }

        $nearest = null;

        foreach ($distributions as $distribution) {
            $distance = $this->calculateDistanceKm(
                $latitude,
                $longitude,
                (float) $distribution->latitude,
                (float) $distribution->longitude
            );

            if ($nearest === null || $distance < $nearest['distance']) {
                $nearest = [
                    'distance' => $distance,
                    'radius' => $distribution->radius_km !== null
                        ? (float) $distribution->radius_km
                        : self::DEFAULT_RADIUS_KM,
                ];
            }
        }

        $distance = round($nearest['distance'], 2);

        if ($distance <= $nearest['radius']) {
            return [
                'result' => 'match',
                'distance_to_known_distribution_km' => $distance,
                'message' => 'Identified species is within known distribution range.',
            ];
        }

        if ($distance <= self::NEARBY_THRESHOLD_KM) {
            return [
                'result' => 'likely_found',
                'distance_to_known_distribution_km' => $distance,
                'message' => 'Identified species is near a known distribution area.',
            ];
        }

        return [
            'result' => 'mismatch',
            'distance_to_known_distribution_km' => $distance,
            'message' => 'Identified species is outside known distribution range.',
        ];
    }

    public function calculateDistanceKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadiusKm = 6371.0;

        $latDelta = deg2rad($lat2 - $lat1);
        $lonDelta = deg2rad($lon2 - $lon1);

        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lonDelta / 2) ** 2;

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadiusKm * $c;
    }
}
