<?php

namespace Database\Seeders;

use App\Models\Species;
use Illuminate\Database\Seeder;

class SpeciesSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $speciesList = [
            [
                'scientific_name' => 'Rhizophora apiculata',
                'common_name' => 'Red Mangrove',
                'family' => 'Rhizophoraceae',
                'identification_notes' => 'CNN class label: Rhizophora_apiculata',
                'habitat' => 'Brackish water, muddy coastal areas',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Rhizophora mucronata',
                'common_name' => 'Red Mangrove',
                'family' => 'Rhizophoraceae',
                'identification_notes' => 'CNN class label: Rhizophora_mucronata',
                'habitat' => 'Intertidal forests and muddy shores',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Rhizophora stylosa',
                'common_name' => 'Stilted mangrove / loop-root mangrove',
                'family' => 'Rhizophoraceae',
                'identification_notes' => 'CNN class label: Rhizophora_stylosa',
                'habitat' => 'Intertidal mangrove forests, estuaries, and sheltered coastal zones',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Avicennia marina',
                'common_name' => 'Grey Mangrove',
                'family' => 'Acanthaceae',
                'identification_notes' => 'CNN class label: Avicennia_marina',
                'habitat' => 'Coastal areas and intertidal zones',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Avicennia marina var. rumphiana',
                'common_name' => 'Api-api / gray mangrove variety',
                'family' => 'Acanthaceae',
                'identification_notes' => 'CNN class label: Avicennia_marina_var_rumphiana',
                'habitat' => 'Coastal and intertidal mangrove zones',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Sonneratia alba',
                'common_name' => 'Milky Mangrove',
                'family' => 'Lythraceae',
                'identification_notes' => 'CNN class label: Sonneratia_alba',
                'habitat' => 'Mudflats and coastal margins',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Bruguiera gymnorrhiza',
                'common_name' => 'Large-leaved Orange Mangrove',
                'family' => 'Rhizophoraceae',
                'identification_notes' => 'CNN class label: Bruguiera_gymnorrhiza',
                'habitat' => 'Brackish water and mangrove forests',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Ceriops tagal',
                'common_name' => 'Tangal',
                'family' => 'Rhizophoraceae',
                'identification_notes' => 'CNN class label: Ceriops_tagal',
                'habitat' => 'Brackish water and inner mangrove zones',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Excoecaria agallocha',
                'common_name' => 'Blind-your-eye mangrove / milky mangrove',
                'family' => 'Euphorbiaceae',
                'identification_notes' => 'CNN class label: Excoecaria_agallocha',
                'habitat' => 'Mangrove margins, tidal creeks, and brackish coastal wetlands',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Xylocarpus granatum',
                'common_name' => 'Cannonball Mangrove',
                'family' => 'Meliaceae',
                'identification_notes' => 'CNN class label: Xylocarpus_granatum',
                'habitat' => 'Mangrove forests and tidal areas',
                'conservation_status' => 'Vulnerable',
                'native_status' => 'Native',
            ],
        ];

        // Demo coordinates are placeholders and must be replaced by verified ecological distribution data.
        $distributions = [
            [
                'location_name' => 'Bontoc, Southern Leyte',
                'province' => 'Southern Leyte',
                'municipality' => 'Bontoc',
                'barangay' => null,
                'latitude' => 10.3550000,
                'longitude' => 124.9650000,
                'radius_km' => 10.00,
            ],
            [
                'location_name' => 'San Ramon, Bontoc, Southern Leyte',
                'province' => 'Southern Leyte',
                'municipality' => 'Bontoc',
                'barangay' => 'San Ramon',
                'latitude' => 10.3450000,
                'longitude' => 124.9800000,
                'radius_km' => 5.00,
            ],
            [
                'location_name' => 'Puerto Princesa, Palawan',
                'province' => 'Palawan',
                'municipality' => 'Puerto Princesa',
                'barangay' => null,
                'latitude' => 9.7400000,
                'longitude' => 118.7350000,
                'radius_km' => 20.00,
            ],
        ];

        foreach ($speciesList as $speciesData) {
            $species = Species::updateOrCreate(
                ['scientific_name' => $speciesData['scientific_name']],
                $speciesData + ['status' => 'active']
            );

            foreach ($distributions as $distribution) {
                $species->distributions()->updateOrCreate(
                    [
                        'location_name' => $distribution['location_name'],
                        'province' => $distribution['province'],
                        'municipality' => $distribution['municipality'],
                        'barangay' => $distribution['barangay'],
                    ],
                    $distribution + [
                        'notes' => 'Demo distribution placeholder. Replace with verified ecological distribution data.',
                    ]
                );
            }
        }
    }
}
