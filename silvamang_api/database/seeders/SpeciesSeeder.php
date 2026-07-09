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
                'habitat' => 'Brackish water, muddy coastal areas',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Rhizophora mucronata',
                'common_name' => 'Red Mangrove',
                'family' => 'Rhizophoraceae',
                'habitat' => 'Intertidal forests and muddy shores',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Avicennia marina',
                'common_name' => 'Grey Mangrove',
                'family' => 'Acanthaceae',
                'habitat' => 'Coastal areas and intertidal zones',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Sonneratia alba',
                'common_name' => 'Milky Mangrove',
                'family' => 'Lythraceae',
                'habitat' => 'Mudflats and coastal margins',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Bruguiera gymnorrhiza',
                'common_name' => 'Large-leaved Orange Mangrove',
                'family' => 'Rhizophoraceae',
                'habitat' => 'Brackish water and mangrove forests',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Ceriops tagal',
                'common_name' => 'Tangal',
                'family' => 'Rhizophoraceae',
                'habitat' => 'Brackish water and inner mangrove zones',
                'conservation_status' => 'Least Concern',
                'native_status' => 'Native',
            ],
            [
                'scientific_name' => 'Xylocarpus granatum',
                'common_name' => 'Cannonball Mangrove',
                'family' => 'Meliaceae',
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
