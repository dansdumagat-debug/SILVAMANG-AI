<?php

namespace App\Services;

use App\Models\ScanRecord;
use App\Models\Species;
use Illuminate\Support\Str;

class MangroveAssistantService
{
    public function answer(string $question, ?ScanRecord $scanRecord = null): array
    {
        $intent = $this->detectIntent($question);
        $species = $this->findSpeciesInQuestion($question) ?? $scanRecord?->species;

        if ($species instanceof Species) {
            if (in_array($intent, ['unknown', 'general_mangrove'], true)) {
                $intent = 'species_information';
            }

            $response = $this->speciesResponse($species, $intent);
        } else {
            $response = $this->responseForIntent($intent);
        }

        if ($scanRecord instanceof ScanRecord) {
            $response .= "\n\n" . $this->scanRecordContext($scanRecord, $intent);
        }

        return [
            'response' => trim($response),
            'intent' => $intent === 'unknown' ? 'offline_unavailable' : $intent,
            'source' => 'laravel_rule_based_assistant',
        ];
    }

    private function detectIntent(string $question): string
    {
        $question = $this->normalizedQuestion($question);

        if ($this->isFollowUpPrompt($question)) {
            return 'general_mangrove';
        }

        if (! $this->isMangroveRelatedQuestion($question)) {
            return 'unknown';
        }

        if ($this->containsAny($question, ['blue carbon', 'store carbon', 'carbon storage', 'climate'])) {
            return 'blue_carbon';
        }

        if ($this->containsAny($question, ['marine life', 'animal', 'animals', 'wildlife', 'fish', 'crab', 'nursery'])) {
            return 'marine_life';
        }

        if ($this->containsAny($question, ['coastal protection', 'protect coast', 'protect shore', 'shoreline', 'waves', 'storm surge', 'erosion'])) {
            return 'coastal_protection';
        }

        if ($this->containsAny($question, ['ecological role', 'ecosystem', 'importance', 'benefit', 'benefits'])) {
            return 'ecological_role';
        }

        if ($this->containsAny($question, ['conservation', 'protect', 'threat', 'danger', 'cutting', 'pollution'])) {
            return 'conservation';
        }

        if ($this->containsAny($question, ['height', 'canopy', 'measurement', 'measure', 'dbh'])) {
            return 'measurement';
        }

        if ($this->containsAny($question, ['prop root', 'stilt root', 'pneumatophore', 'breathing root', 'root type'])) {
            return 'root_types';
        }

        if ($this->containsAny($question, ['salty water', 'salt water', 'salinity', 'salt tolerant', 'adaptation', 'adaptations'])) {
            return 'adaptations';
        }

        if ($this->containsAny($question, ['reproduce', 'reproduction', 'propagule', 'seedling', 'seed'])) {
            return 'reproduction';
        }

        if ($this->containsAny($question, ['zonation', 'zone', 'seaward', 'landward', 'tidal zone'])) {
            return 'zonation';
        }

        if ($this->containsAny($question, ['philippines', 'southeast asia', 'distribution', 'grow in'])) {
            return 'distribution';
        }

        if ($this->containsAny($question, ['location', 'gps', 'validation', 'match', 'mismatch', 'distribution'])) {
            return 'location_validation';
        }

        if ($this->containsAny($question, ['identify', 'identification', 'prediction', 'confidence', 'result'])) {
            return 'identification_result';
        }

        if ($this->containsAny($question, ['species', 'scientific name', 'common name', 'family', 'habitat'])) {
            return 'species_information';
        }

        return 'general_mangrove';
    }

    private function findSpeciesInQuestion(string $question): ?Species
    {
        $question = $this->normalizedQuestion($question);

        return Species::query()
            ->where('status', 'active')
            ->get()
            ->first(function (Species $species) use ($question) {
                $scientificName = Str::lower((string) $species->scientific_name);
                $commonName = Str::lower((string) $species->common_name);

                return ($scientificName !== '' && str_contains($question, $scientificName))
                    || ($commonName !== '' && str_contains($question, $commonName));
            });
    }

    private function speciesResponse(Species $species, string $intent): string
    {
        $parts = [
            "{$species->scientific_name} ({$species->common_name}) belongs to the {$species->family} family.",
        ];

        if ($species->habitat) {
            $parts[] = "Habitat: {$species->habitat}";
        }

        if ($species->conservation_status) {
            $parts[] = "Conservation status: {$species->conservation_status}.";
        }

        if ($intent === 'ecological_role' && $species->ecological_role) {
            $parts[] = "Ecological role: {$species->ecological_role}";
        } elseif ($species->ecological_role) {
            $parts[] = "It supports mangrove ecosystems through roles such as habitat support, shoreline protection, and biodiversity value. {$species->ecological_role}";
        }

        if ($species->identification_notes) {
            $parts[] = "Identification notes: {$species->identification_notes}";
        }

        return implode(' ', $parts);
    }

    private function responseForIntent(string $intent): string
    {
        return match ($intent) {
            'general_mangrove' => 'Mangroves are special coastal trees and shrubs that can live in salty, muddy, and tidal areas. They are important because their roots protect shorelines from waves, reduce erosion, trap sediment, provide nursery habitat for fish and crabs, and store blue carbon that helps with climate protection. In simple terms, mangroves act like a natural shield and nursery for coastal communities.',
            'ecological_role' => 'Mangroves protect coastlines from waves and storm surge, reduce erosion, store large amounts of carbon, provide habitat and nursery areas for marine life, and support high biodiversity in coastal ecosystems.',
            'coastal_protection' => 'Mangroves protect coastal areas by slowing waves, reducing storm surge force, trapping sediment, and holding muddy shorelines together with dense roots.',
            'marine_life' => 'Mangrove roots provide nursery habitat, shelter, and feeding areas for fish, crabs, shrimp, mollusks, birds, and many other coastal organisms.',
            'blue_carbon' => 'Mangroves store blue carbon in trunks, branches, roots, and especially in waterlogged soils where plant material breaks down slowly.',
            'conservation' => 'Mangrove conservation focuses on avoiding cutting, protecting habitat, supporting reforestation, reducing pollution, and verifying species records for long-term monitoring and restoration planning.',
            'measurement' => 'Current height, canopy, and DBH values are prototype depth-estimation measurements. Real MiDaS integration is planned, and estimates may vary depending on image angle, distance, lighting, and reference scale.',
            'root_types' => 'Mangrove roots help trees survive in soft, salty, waterlogged soil. Rhizophora commonly has prop or stilt roots for support. Avicennia and Sonneratia can have pneumatophores, which are breathing roots that rise from the mud.',
            'adaptations' => 'Mangrove adaptations include salt filtering, salt excretion, thick leaves, floating propagules, support roots, and breathing roots that help trees survive salty tides and low-oxygen mud.',
            'reproduction' => 'Many mangroves reproduce through propagules that can float with tides before settling in suitable mud. Seedling survival depends on tides, salinity, sediment, sunlight, and protection from disturbance.',
            'zonation' => 'Mangrove zonation means different species occupy different coastal zones depending on tides, salinity, elevation, sediment, wave exposure, and freshwater input.',
            'distribution' => 'Philippine mangrove areas can include Rhizophora, Avicennia, Bruguiera, Ceriops, Sonneratia, Excoecaria, and Xylocarpus species. Local confirmation should use field keys and verified distribution records.',
            'location_validation' => 'Location validation compares GPS coordinates with known species distribution records. A match means the species is within a known range, while a mismatch may mean the observation is outside the expected area or that distribution data is incomplete.',
            'identification_result' => 'Identification results show the predicted mangrove species, confidence score, and top-k alternatives. Higher confidence suggests stronger model agreement, but field verification is still recommended for research-quality records.',
            default => 'I can help with mangrove species, root types, habitats, ecology, conservation, identification results, location validation, and field measurements. You can ask about a species such as Rhizophora apiculata, or ask for benefits, zonation, roots, threats, or field identification tips.',
        };
    }

    private function scanRecordContext(ScanRecord $scanRecord, string $intent): string
    {
        $parts = [];

        $name = $scanRecord->top_scientific_name ?? $scanRecord->species?->scientific_name;
        if ($name) {
            $commonName = $scanRecord->top_common_name ?? $scanRecord->species?->common_name;
            $confidence = $scanRecord->confidence !== null ? " with {$scanRecord->confidence}% confidence" : '';
            $parts[] = "Linked scan record result: {$name}" . ($commonName ? " ({$commonName})" : '') . "{$confidence}.";
        }

        if ($scanRecord->validation_status) {
            $parts[] = "Validation status: {$scanRecord->validation_status}.";
        }

        if ($scanRecord->location_name) {
            $parts[] = "Location: {$scanRecord->location_name}.";
        }

        if ($intent === 'measurement' && $scanRecord->measurement) {
            $measurement = $scanRecord->measurement;
            $parts[] = "Measurement record: height {$measurement->height_m} m, canopy width {$measurement->canopy_width_m} m, DBH " . ($measurement->dbh_cm ?? 'N/A') . " cm, method {$measurement->measurement_method}.";
        }

        if ($intent === 'location_validation' && $scanRecord->locationValidation) {
            $validation = $scanRecord->locationValidation;
            $parts[] = "Location validation result: {$validation->result}. {$validation->message}";
        }

        return $parts
            ? implode(' ', $parts)
            : 'A linked scan record was provided, but it does not yet contain enough detail for a record-specific explanation.';
    }

    private function containsAny(string $value, array $needles): bool
    {
        foreach ($needles as $needle) {
            if (str_contains($value, $needle)) {
                return true;
            }
        }

        return false;
    }

    private function isMangroveRelatedQuestion(string $question): bool
    {
        $question = $this->normalizedQuestion($question);

        return $this->containsAny($question, [
            'mangrove',
            'mangroves',
            'rhizophora',
            'avicennia',
            'bruguiera',
            'ceriops',
            'sonneratia',
            'xylocarpus',
            'excoecaria',
            'species',
            'ecology',
            'biodiversity',
            'root',
            'roots',
            'prop root',
            'stilt root',
            'pneumatophore',
            'propagule',
            'seedling',
            'coastal',
            'shoreline',
            'estuary',
            'estuarine',
            'tidal',
            'mudflat',
            'ecosystem',
            'conservation',
            'restoration',
            'reforestation',
            'protect',
            'benefit',
            'carbon',
            'salinity',
            'salt',
            'zonation',
            'habitat',
            'gps',
            'location',
            'scan',
            'identify',
            'identification',
            'measurement',
            'height',
            'canopy',
        ]);
    }

    private function isFollowUpPrompt(string $question): bool
    {
        $question = trim($this->normalizedQuestion($question));

        return in_array($question, [
            'more',
            'tell me more',
            'continue',
            'go on',
            'explain more',
            'more details',
            'more info',
            'learn more',
            'tell me more about it',
        ], true)
            || $this->containsAny($question, [
                'tell me more',
                'explain more',
                'more details',
                'learn more',
                'continue this',
                'continue answer',
            ]);
    }

    private function normalizedQuestion(string $question): string
    {
        $question = Str::lower($question);

        return str_replace(
            [
                'manggroves',
                'manggrovess',
                'manggrove',
                'mangroove',
                'mangrooves',
                'mangrove trees',
            ],
            [
                'mangroves',
                'mangroves',
                'mangrove',
                'mangrove',
                'mangroves',
                'mangroves',
            ],
            $question
        );
    }
}
