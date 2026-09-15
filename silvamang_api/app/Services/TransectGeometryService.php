<?php

namespace App\Services;

class TransectGeometryService
{
    private const EARTH_RADIUS_M = 6371000.0;

    /**
     * @param  array<int, array{latitude: float|int|string, longitude: float|int|string}>  $points
     * @return array{distance_m: float, bearing_degrees: ?float, geometry: array<string, mixed>}
     */
    public function summarize(array $points): array
    {
        $distance = 0.0;

        for ($index = 1; $index < count($points); $index++) {
            $distance += $this->distanceMeters($points[$index - 1], $points[$index]);
        }

        return [
            'distance_m' => round($distance, 2),
            'bearing_degrees' => count($points) >= 2
                ? round($this->initialBearing($points[0], $points[array_key_last($points)]), 2)
                : null,
            'geometry' => [
                'type' => 'LineString',
                'coordinates' => array_map(
                    fn (array $point) => [(float) $point['longitude'], (float) $point['latitude']],
                    $points
                ),
            ],
        ];
    }

    /**
     * @param  array{latitude: float|int|string, longitude: float|int|string}  $from
     * @param  array{latitude: float|int|string, longitude: float|int|string}  $to
     */
    public function distanceMeters(array $from, array $to): float
    {
        $latitude1 = deg2rad((float) $from['latitude']);
        $latitude2 = deg2rad((float) $to['latitude']);
        $latitudeDelta = $latitude2 - $latitude1;
        $longitudeDelta = deg2rad((float) $to['longitude'] - (float) $from['longitude']);

        $a = sin($latitudeDelta / 2) ** 2
            + cos($latitude1) * cos($latitude2) * sin($longitudeDelta / 2) ** 2;

        return self::EARTH_RADIUS_M * 2 * atan2(sqrt($a), sqrt(max(0.0, 1 - $a)));
    }

    /**
     * @param  array{latitude: float|int|string, longitude: float|int|string}  $from
     * @param  array{latitude: float|int|string, longitude: float|int|string}  $to
     */
    public function initialBearing(array $from, array $to): float
    {
        $latitude1 = deg2rad((float) $from['latitude']);
        $latitude2 = deg2rad((float) $to['latitude']);
        $longitudeDelta = deg2rad((float) $to['longitude'] - (float) $from['longitude']);

        $y = sin($longitudeDelta) * cos($latitude2);
        $x = cos($latitude1) * sin($latitude2)
            - sin($latitude1) * cos($latitude2) * cos($longitudeDelta);

        return fmod(rad2deg(atan2($y, $x)) + 360.0, 360.0);
    }
}
