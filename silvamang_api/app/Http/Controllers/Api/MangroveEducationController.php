<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MangroveEducationResource;
use App\Models\MangroveEducation;
use App\Models\Species;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class MangroveEducationController extends Controller
{
    public function show(Request $request)
    {
        $data = $request->validate([
            'species_name' => ['required', 'string', 'max:255'],
        ]);

        $speciesName = $this->normalizeSpeciesName($data['species_name']);
        $species = Species::query()
            ->get()
            ->first(fn (Species $item) => $this->normalizeSpeciesName($item->scientific_name) === $speciesName);

        if (! $species) {
            return response()->json([
                'message' => 'Educational information is not available for this species.',
            ], 404);
        }

        if (Schema::hasTable('mangrove_education')) {
            $education = MangroveEducation::query()
                ->with('species')
                ->where('species_id', $species->id)
                ->where('status', 'active')
                ->first();

            if ($education) {
                return response()->json([
                    'message' => 'Mangrove education retrieved successfully.',
                    'data' => new MangroveEducationResource($education),
                ]);
            }
        }

        return response()->json([
            'message' => 'Species profile education retrieved from species record.',
            'data' => $this->fallbackFromSpecies($species),
        ]);
    }

    private function normalizeSpeciesName(string $name): string
    {
        return Str::of($name)
            ->replace('_', ' ')
            ->squish()
            ->lower()
            ->toString();
    }

    /**
     * @return array<string, mixed>
     */
    private function fallbackFromSpecies(Species $species): array
    {
        return [
            'id' => null,
            'species_id' => null,
            'scientific_name' => $species->scientific_name,
            'display_name' => $species->scientific_name,
            'common_name' => $species->common_name,
            'family' => $species->family,
            'overview' => $species->description,
            'description' => $species->description,
            'physical_characteristics' => array_values(array_filter([
                $species->identification_notes,
                $species->max_height_m ? "Can reach about {$species->max_height_m} meters where conditions are suitable." : null,
            ])),
            'leaf_characteristics' => null,
            'root_characteristics' => null,
            'habitat' => $this->splitText($species->habitat),
            'distribution' => $this->splitText($species->distribution_notes),
            'ecological_importance' => $this->splitText($species->ecological_role),
            'history' => $this->generalHistory(),
            'scientific_study' => $this->generalScientificStudy(),
            'conservation_information' => array_values(array_filter([
                $species->conservation_status ? "Conservation status: {$species->conservation_status}." : null,
                'Protect mangroves by avoiding cutting, pollution, blocked tidal flow, and poorly planned coastal development.',
            ])),
            'conservation_note' => 'Mangroves support biodiversity, coastal protection, and climate resilience.',
            'interesting_facts' => [
                'Mangrove forests can store large amounts of carbon in roots and waterlogged soil.',
                'Mangrove roots provide nursery shelter for young fish and crabs.',
            ],
            'trivia' => [
                'Mangrove forests can store large amounts of carbon in roots and waterlogged soil.',
                'Mangrove roots provide nursery shelter for young fish and crabs.',
            ],
            'references' => [
                'Tomlinson, P. B. The Botany of Mangroves.',
                'Spalding, Kainuma, and Collins. World Atlas of Mangroves.',
                'FAO mangrove conservation and restoration guidance.',
            ],
            'location_validation_hint' => 'commonly_found',
            'status' => 'species_profile_fallback',
        ];
    }

    /**
     * @return array<int, string>
     */
    private function splitText(?string $text): array
    {
        if (! $text) {
            return [];
        }

        return collect(preg_split('/[,;\n]+/', $text) ?: [])
            ->map(fn (string $item) => trim($item))
            ->filter()
            ->values()
            ->all();
    }

    private function generalHistory(): string
    {
        return 'Mangroves were known and used by coastal communities for centuries before formal scientific study. Communities used mangrove areas for shoreline protection, food gathering, timber, medicine, navigation, and fishing support.';
    }

    private function generalScientificStudy(): string
    {
        return 'Modern mangrove research documented species taxonomy, salt tolerance, root adaptations, coastal protection, nursery habitat, and blue-carbon storage. Researchers now study mangroves through field surveys, herbarium records, ecological monitoring, remote sensing, and community-based conservation.';
    }
}
