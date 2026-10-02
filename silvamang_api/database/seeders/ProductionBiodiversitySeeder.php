<?php

namespace Database\Seeders;

use App\Models\ExternalSpeciesObservation;
use App\Models\Species;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use RuntimeException;

/** Import the bundled public reference cache without copying local database IDs. */
class ProductionBiodiversitySeeder extends Seeder
{
    public function run(): void
    {
        $snapshot = json_decode(file_get_contents(database_path('data/external_biodiversity_references.json')), true, 512, JSON_THROW_ON_ERROR);
        Validator::make($snapshot, [
            'schema_version' => 'required|integer|in:1',
            'observations' => 'required|array|min:1',
            'observations.*.scientific_name' => 'required|string|max:255',
            'observations.*.source' => 'required|in:inaturalist',
            'observations.*.source_observation_id' => 'required|string|regex:/^[0-9]+$/|distinct|max:255',
            'observations.*.photo_url' => 'nullable|url|max:255',
            'observations.*.observer' => 'nullable|string|max:255',
            'observations.*.location' => 'nullable|string|max:255',
            'observations.*.latitude' => 'nullable|numeric|between:-90,90',
            'observations.*.longitude' => 'nullable|numeric|between:-180,180',
            'observations.*.observed_date' => 'nullable|date_format:Y-m-d',
            'observations.*.quality_grade' => 'nullable|string|max:255',
        ])->validate();

        $inserted = DB::transaction(function () use ($snapshot): int {
            $inserted = 0;
            foreach ($snapshot['observations'] as $row) {
                $matches = Species::where('scientific_name', $row['scientific_name'])->get();
                if ($matches->count() !== 1) {
                    throw new RuntimeException('Missing or ambiguous species: '.$row['scientific_name'].'. Run ProductionLearningSeeder first and check the species catalog. No references imported.');
                }
                $species = $matches->first();
                $key = ['source' => $row['source'], 'source_observation_id' => $row['source_observation_id']];
                $existing = ExternalSpeciesObservation::where($key)->first();
                if ($existing && (int) $existing->species_id !== (int) $species->id) {
                    throw new RuntimeException('Species conflict for observation '.$row['source_observation_id'].'. No references imported.');
                }
                if ($existing) {
                    continue; // Preserve newer production cache values and timestamps.
                }
                $values = array_intersect_key($row, array_flip([
                    'photo_url', 'observer', 'location', 'latitude', 'longitude', 'observed_date', 'quality_grade',
                ]));
                ExternalSpeciesObservation::create($key + $values + ['species_id' => $species->id]);
                $inserted++;
            }

            return $inserted;
        });

        $this->command?->info("Imported {$inserted} biodiversity references; existing records preserved.");
    }
}
