<?php

namespace Database\Seeders;

use App\Models\MangroveKnowledge;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class MangroveKnowledgeSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('mangrove_knowledge')) {
            return;
        }

        foreach ($this->entries() as $entry) {
            $payload = [
                'category' => $entry['category'],
                'answer' => $entry['answer'],
                'species_name' => $entry['species_name'] ?? null,
                'keywords' => $entry['keywords'],
            ];

            if (Schema::hasColumn('mangrove_knowledge', 'related_species')) {
                $payload['related_species'] = $entry['related_species'] ?? null;
            }

            if (Schema::hasColumn('mangrove_knowledge', 'status')) {
                $payload['status'] = 'active';
            }

            if (Schema::hasColumn('mangrove_knowledge', 'reference_source')) {
                $payload['reference_source'] = $entry['reference_source'] ?? 'SILVAMANG AI verified local knowledge base';
            }

            MangroveKnowledge::updateOrCreate(
                ['question' => $entry['question']],
                $payload
            );
        }
    }

    /**
     * @return array<int, array<string, string|null>>
     */
    private function entries(): array
    {
        return [
            [
                'category' => 'general_mangrove',
                'question' => 'What is a mangrove?',
                'answer' => 'Mangroves are salt-tolerant trees and shrubs that grow in coastal intertidal areas. They protect shorelines, trap sediment, provide wildlife habitat, and store blue carbon.',
                'species_name' => null,
                'related_species' => null,
                'keywords' => 'mangrove, definition, coastal, intertidal, salt tolerant',
            ],
            [
                'category' => 'ecology',
                'question' => 'Why are mangroves important?',
                'answer' => 'Mangroves reduce wave energy, slow storm surge, prevent coastal erosion, provide nursery habitat for fish and crabs, filter sediment, and store carbon in roots and soil.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Avicennia marina, Sonneratia alba',
                'keywords' => 'importance, ecology, carbon, nursery, erosion, storm surge',
            ],
            [
                'category' => 'ecology',
                'question' => 'How do mangroves protect coastal areas?',
                'answer' => 'Mangroves protect coastal areas by slowing waves, reducing storm surge force, trapping sediment, and holding muddy shorelines together with dense roots.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Rhizophora mucronata, Sonneratia alba, Avicennia marina',
                'keywords' => 'coastal protection, shoreline, waves, storm surge, erosion, sediment',
            ],
            [
                'category' => 'ecology',
                'question' => 'How do mangroves help marine life?',
                'answer' => 'Mangrove roots create shelter, feeding areas, and nursery habitat for young fish, crabs, shrimp, mollusks, and other coastal animals.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Avicennia marina, Sonneratia alba',
                'keywords' => 'marine life, nursery, fish, crabs, shrimp, animals, wildlife, habitat',
            ],
            [
                'category' => 'ecology',
                'question' => 'How do mangroves store carbon?',
                'answer' => 'Mangroves store blue carbon in trunks, branches, roots, and especially in waterlogged soils where dead plant material breaks down slowly.',
                'species_name' => null,
                'related_species' => null,
                'keywords' => 'blue carbon, carbon storage, climate, soil carbon',
            ],
            [
                'category' => 'species_information',
                'question' => 'What is Rhizophora apiculata?',
                'answer' => 'Rhizophora apiculata is a true mangrove species known for strong stilt roots, opposite leaves, and propagules. It is commonly associated with muddy shorelines, estuaries, and sheltered coasts.',
                'species_name' => 'Rhizophora apiculata',
                'related_species' => 'Rhizophora apiculata',
                'keywords' => 'rhizophora, apiculata, red mangrove, stilt roots, propagules',
            ],
            [
                'category' => 'mangrove_biology',
                'question' => 'What are prop roots?',
                'answer' => 'Prop roots, also called stilt roots, grow from stems or branches into the mud. They help mangroves stand in soft sediment, resist waves, and exchange gases in waterlogged areas.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Rhizophora mucronata, Rhizophora stylosa',
                'keywords' => 'prop roots, stilt roots, rhizophora, roots, support',
            ],
            [
                'category' => 'mangrove_biology',
                'question' => 'Why do mangroves survive in salty water?',
                'answer' => 'Mangroves survive salty water through adaptations such as filtering salt at the roots, storing or excreting extra salt through leaves, reducing water loss with thick leaves, and using special roots for low-oxygen mud.',
                'species_name' => null,
                'related_species' => 'Avicennia marina, Rhizophora apiculata, Sonneratia alba',
                'keywords' => 'salty water, salt water, salinity, salt tolerant, adaptations',
            ],
            [
                'category' => 'mangrove_biology',
                'question' => 'What are mangrove adaptations?',
                'answer' => 'Mangrove adaptations include salt filtering, salt excretion, thick leaves, floating propagules, support roots, and breathing roots such as pneumatophores.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Avicennia marina, Sonneratia alba, Bruguiera gymnorrhiza',
                'keywords' => 'adaptations, salt, breathing roots, pneumatophores, propagules',
            ],
            [
                'category' => 'identification_guide',
                'question' => 'What is the difference between Rhizophora and Avicennia?',
                'answer' => 'Rhizophora species usually show stilt or prop roots. Avicennia species often show pencil-like pneumatophores rising from the soil. Use roots, leaves, bark, flowers, propagules, habitat, and GPS context together.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Rhizophora mucronata, Rhizophora stylosa, Avicennia marina',
                'keywords' => 'rhizophora, avicennia, difference, stilt roots, pneumatophores',
            ],
            [
                'category' => 'distribution',
                'question' => 'What mangrove species grow in the Philippines?',
                'answer' => 'The Philippines has many true mangrove and mangrove-associated species. SILVAMANG currently focuses on Rhizophora, Avicennia, Bruguiera, Ceriops, Sonneratia, Excoecaria, and Xylocarpus species.',
                'species_name' => null,
                'related_species' => 'Rhizophora apiculata, Avicennia marina, Bruguiera gymnorrhiza, Ceriops tagal, Sonneratia alba, Xylocarpus granatum',
                'keywords' => 'philippines, species, distribution, southeast asia',
            ],
            [
                'category' => 'conservation',
                'question' => 'How can I protect mangroves?',
                'answer' => 'Protect mangroves by avoiding cutting, preventing waste dumping, reporting illegal clearing, preserving tidal flow, planting suitable native species, and monitoring survival after restoration.',
                'species_name' => null,
                'related_species' => null,
                'keywords' => 'protect, conservation, threat, illegal cutting, pollution, restoration',
            ],
            [
                'category' => 'conservation',
                'question' => 'What threatens mangrove ecosystems?',
                'answer' => 'Mangrove ecosystems are threatened by cutting, land conversion, fishpond expansion, pollution, blocked tidal flow, poorly planned planting, sediment changes, and climate-related sea level rise.',
                'species_name' => null,
                'related_species' => null,
                'keywords' => 'threats, cutting, pollution, fishpond, land conversion, sea level rise',
            ],
            [
                'category' => 'environmental_education',
                'question' => 'What animals live in mangroves?',
                'answer' => 'Mangroves provide habitat for fish, crabs, shrimp, mollusks, insects, birds, reptiles, and many microorganisms.',
                'species_name' => null,
                'related_species' => null,
                'keywords' => 'animals, wildlife, fish, crabs, birds, shrimp, habitat, marine life',
            ],
            [
                'category' => 'location_information',
                'question' => 'How does location validation work?',
                'answer' => 'Location validation compares phone GPS coordinates with species distribution or boundary data. GPS gives latitude and longitude only; barangay names require boundary polygons or verified local lookup data.',
                'species_name' => null,
                'related_species' => null,
                'keywords' => 'location, gps, barangay, validation, boundary, coordinates',
            ],
        ];
    }
}
