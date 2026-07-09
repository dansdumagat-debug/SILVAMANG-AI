<?php

namespace Database\Seeders;

use App\Models\Measurement;
use App\Models\Prediction;
use App\Models\ScanRecord;
use App\Models\Species;
use Illuminate\Database\Seeder;

class DemoScanRecordSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $species = Species::where('scientific_name', 'Rhizophora apiculata')->firstOrFail();

        $scanRecord = ScanRecord::updateOrCreate(
            ['record_code' => 'SC-DEMO-0001'],
            [
                'species_id' => $species->id,
                'top_scientific_name' => 'Rhizophora apiculata',
                'top_common_name' => 'Red Mangrove',
                'confidence' => 92.40,
                'capture_mode' => 'guided',
                'identification_status' => 'completed',
                'validation_status' => 'match',
                'location_name' => 'Brgy. San Roque, Puerto Princesa, Palawan',
                'notes' => 'Demo scan record for Phase 2 API testing.',
                'captured_at' => now(),
            ]
        );

        $predictions = [
            ['rank' => 1, 'scientific_name' => 'Rhizophora apiculata', 'common_name' => 'Red Mangrove', 'confidence' => 92.40],
            ['rank' => 2, 'scientific_name' => 'Rhizophora mucronata', 'common_name' => 'Red Mangrove', 'confidence' => 5.10],
            ['rank' => 3, 'scientific_name' => 'Bruguiera gymnorrhiza', 'common_name' => 'Large-leaved Orange Mangrove', 'confidence' => 2.50],
        ];

        foreach ($predictions as $prediction) {
            $predictionSpecies = Species::where('scientific_name', $prediction['scientific_name'])->first();

            Prediction::updateOrCreate(
                [
                    'scan_record_id' => $scanRecord->id,
                    'rank' => $prediction['rank'],
                ],
                $prediction + [
                    'scan_record_id' => $scanRecord->id,
                    'species_id' => $predictionSpecies?->id,
                ]
            );
        }

        Measurement::updateOrCreate(
            ['scan_record_id' => $scanRecord->id],
            [
                'height_m' => 6.80,
                'canopy_width_m' => 4.20,
                'measurement_method' => 'depth_estimation',
                'confidence' => 88.00,
                'measured_at' => now(),
            ]
        );

        $scanRecord->locationValidation()->updateOrCreate(
            ['scan_record_id' => $scanRecord->id],
            [
                'species_id' => $species->id,
                'result' => 'match',
                'message' => 'Species is commonly found in this area.',
                'validated_at' => now(),
            ]
        );
    }
}
