<?php

namespace Database\Seeders;

use App\Models\ScanRecord;
use App\Models\Transect;
use App\Models\User;
use App\Services\TransectGeometryService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class TransectDemoSeeder extends Seeder
{
    public function run(): void
    {
        $owner = User::query()
            ->where('email', 'admin@silvamang.test')
            ->first() ?? User::query()->orderBy('id')->first();

        if (! $owner) {
            return;
        }

        $recordedAt = now()->subDay()->startOfHour();
        $points = [
            [
                'latitude' => 10.3549863,
                'longitude' => 124.9670588,
                'accuracy_m' => 4.8,
                'altitude_m' => 2.1,
                'recorded_at' => $recordedAt,
            ],
            [
                'latitude' => 10.3556000,
                'longitude' => 124.9677000,
                'accuracy_m' => 5.3,
                'altitude_m' => 2.0,
                'recorded_at' => $recordedAt->copy()->addMinutes(2),
            ],
            [
                'latitude' => 10.3563194,
                'longitude' => 124.9685442,
                'accuracy_m' => 5.9,
                'altitude_m' => 1.8,
                'recorded_at' => $recordedAt->copy()->addMinutes(5),
            ],
        ];
        $summary = app(TransectGeometryService::class)->summarize($points);

        DB::transaction(function () use ($owner, $points, $summary, $recordedAt) {
            $transect = Transect::query()->updateOrCreate(
                ['offline_reference' => 'demo-gps-transect-t1'],
                [
                    'user_id' => $owner->id,
                    'transect_code' => 'TR-DEMO-0001',
                    'transect_name' => 'Sample GPS Transect T1',
                    'location_name' => 'Sample Mangrove Field Site',
                    'description' => 'Demo record for map, distance, observation, and export verification.',
                    'mode' => 'gps_tracking',
                    'status' => 'completed',
                    'start_latitude' => $points[0]['latitude'],
                    'start_longitude' => $points[0]['longitude'],
                    'end_latitude' => $points[array_key_last($points)]['latitude'],
                    'end_longitude' => $points[array_key_last($points)]['longitude'],
                    'total_distance_m' => $summary['distance_m'],
                    'bearing_degrees' => $summary['bearing_degrees'],
                    'gps_accuracy_m' => 5.33,
                    'geometry' => $summary['geometry'],
                    'pending_observation_references' => null,
                    'recorded_at' => $recordedAt,
                    'synced_at' => now(),
                ]
            );

            $transect->points()->delete();
            $transect->points()->createMany(array_map(
                fn (array $point, int $index) => $point + ['sequence_number' => $index + 1],
                $points,
                array_keys($points)
            ));

            $nearbyScanIds = ScanRecord::query()
                ->whereNotNull('latitude')
                ->whereNotNull('longitude')
                ->whereBetween('latitude', [10.35, 10.36])
                ->whereBetween('longitude', [124.96, 124.98])
                ->orderByDesc('captured_at')
                ->limit(3)
                ->pluck('id');
            if ($nearbyScanIds->isEmpty()) {
                $nearbyScanIds = ScanRecord::query()
                    ->where('record_code', 'SC-DEMO-0001')
                    ->pluck('id');
            }
            $transect->observations()->sync($nearbyScanIds);
        });
    }
}
