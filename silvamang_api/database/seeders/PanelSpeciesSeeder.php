<?php

namespace Database\Seeders;

use App\Models\Species;
use App\Support\SpeciesTaxonomy;
use Database\Seeders\Support\PanelSpeciesCatalog;
use Illuminate\Database\Seeder;

class PanelSpeciesSeeder extends Seeder
{
    public function run(): void
    {
        foreach (PanelSpeciesCatalog::entries() as $entry) {
            $scientificName = SpeciesTaxonomy::canonicalName($entry['scientific_name']);

            Species::firstOrCreate(
                ['scientific_name' => $scientificName],
                [
                    'common_name' => $entry['common_name'],
                    'family' => $entry['family'],
                    'genus' => $entry['genus'],
                    'description' => $entry['description'],
                    'habitat' => implode('; ', $entry['habitat']).'. Zonation: '.$entry['zonation'],
                    'distribution_notes' => implode('; ', $entry['distribution']),
                    'ecological_role' => implode('; ', $entry['ecological_importance']),
                    'identification_notes' => implode(' ', [
                        'Leaf: '.$entry['leaf'],
                        'Root: '.$entry['root'],
                        'Bark: '.$entry['bark'],
                        'Flower: '.$entry['flower'],
                        'Fruit/propagule: '.$entry['fruit'],
                        'Knowledge-base species only; not supported by the current 10-class CNN.',
                    ]),
                    'conservation_status' => $entry['conservation_status'],
                    'native_status' => $entry['native_status'],
                    'max_height_m' => $entry['max_height_m'],
                    'status' => 'active',
                    'cnn_supported' => false,
                ]
            );
        }
    }
}
