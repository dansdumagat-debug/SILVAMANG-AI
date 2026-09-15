<?php

namespace Database\Seeders;

use App\Models\MangroveKnowledge;
use Database\Seeders\Support\PanelSpeciesCatalog;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class PanelMangroveKnowledgeSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('mangrove_knowledge')) {
            return;
        }

        foreach (PanelSpeciesCatalog::entries() as $entry) {
            $question = 'How can I identify '.$entry['scientific_name'].'?';
            $payload = [
                'category' => 'species_information',
                'answer' => implode(' ', [
                    $entry['description'],
                    'Leaf: '.$entry['leaf'],
                    'Root: '.$entry['root'],
                    'Bark: '.$entry['bark'],
                    'Flower: '.$entry['flower'],
                    'Fruit or propagule: '.$entry['fruit'],
                    'Zonation: '.$entry['zonation'],
                ]),
                'species_name' => $entry['scientific_name'],
                'keywords' => strtolower(implode(', ', [
                    $entry['scientific_name'],
                    $entry['common_name'],
                    $entry['family'],
                    $entry['genus'],
                    'identification',
                    'mangrove',
                ])),
            ];

            if (Schema::hasColumn('mangrove_knowledge', 'related_species')) {
                $payload['related_species'] = $entry['scientific_name'];
            }

            if (Schema::hasColumn('mangrove_knowledge', 'reference_source')) {
                $payload['reference_source'] = implode("\n", $entry['references']);
            }

            if (Schema::hasColumn('mangrove_knowledge', 'status')) {
                $payload['status'] = 'active';
            }

            MangroveKnowledge::firstOrCreate(
                ['question' => $question],
                $payload
            );
        }
    }
}
