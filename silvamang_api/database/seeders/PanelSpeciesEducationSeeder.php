<?php

namespace Database\Seeders;

use App\Models\MangroveEducation;
use App\Models\Species;
use Database\Seeders\Support\PanelSpeciesCatalog;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class PanelSpeciesEducationSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('mangrove_education')) {
            return;
        }

        foreach (PanelSpeciesCatalog::entries() as $entry) {
            $species = Species::query()
                ->where('scientific_name', $entry['scientific_name'])
                ->first();

            if (! $species) {
                continue;
            }

            MangroveEducation::firstOrCreate(
                ['species_id' => $species->id],
                [
                    'overview' => $entry['description'],
                    'physical_characteristics' => [
                        'Bark: '.$entry['bark'],
                        'Flowers: '.$entry['flower'],
                        'Fruit or propagule: '.$entry['fruit'],
                        'Mangrove zonation: '.$entry['zonation'],
                    ],
                    'leaf_characteristics' => $entry['leaf'],
                    'root_characteristics' => $entry['root'],
                    'habitat' => $entry['habitat'],
                    'distribution' => $entry['distribution'],
                    'ecological_importance' => $entry['ecological_importance'],
                    'history' => $entry['history'],
                    'scientific_study' => $entry['scientific_study'],
                    'conservation_information' => array_merge(
                        ['Recorded conservation status: '.$entry['conservation_status'].'.'],
                        $entry['conservation_information']
                    ),
                    'interesting_facts' => array_merge(
                        $entry['interesting_facts'],
                        ['Future CNN data: '.$entry['cnn_candidate_availability']]
                    ),
                    'references' => $entry['references'],
                    'status' => 'active',
                ]
            );
        }
    }
}
