<?php

namespace Tests\Feature;

use App\Models\ExternalSpeciesObservation;
use App\Models\Species;
use App\Models\User;
use Database\Seeders\ProductionBiodiversitySeeder;
use Database\Seeders\ProductionLearningSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class ProductionBiodiversitySeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_import_maps_names_and_preserves_existing_data_when_repeated(): void
    {
        $user = User::factory()->create();
        // Deliberately shift IDs away from the exported local database.
        Species::create(['scientific_name' => 'Unrelated species', 'common_name' => 'Other']);
        $this->seed(ProductionLearningSeeder::class);
        $this->seed(ProductionBiodiversitySeeder::class);
        $this->assertDatabaseCount('external_species_observations', 36);
        $rows = json_decode(file_get_contents(database_path('data/external_biodiversity_references.json')), true)['observations'];
        foreach ($rows as $row) {
            $record = ExternalSpeciesObservation::where('source_observation_id', $row['source_observation_id'])->firstOrFail();
            $this->assertSame($row['scientific_name'], $record->species->scientific_name);
        }
        $record = ExternalSpeciesObservation::first();
        $record->update(['location' => 'Newer production value']);
        $this->seed(ProductionBiodiversitySeeder::class);
        $this->assertDatabaseCount('external_species_observations', 36);
        $this->assertSame('Newer production value', $record->fresh()->location);
        $this->assertDatabaseCount('users', 1);
        $this->assertNotNull($user->fresh());
        $this->assertDatabaseCount('scan_records', 0);
    }

    public function test_missing_species_rolls_back_the_entire_import(): void
    {
        $this->seed(ProductionLearningSeeder::class);
        Species::where('scientific_name', 'Camptostemon philippinensis')->delete();
        try {
            $this->seed(ProductionBiodiversitySeeder::class);
            $this->fail('Expected missing species to reject import.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('Missing or ambiguous species', $exception->getMessage());
        }
        $this->assertDatabaseCount('external_species_observations', 0);
    }

    public function test_existing_observation_with_conflicting_species_is_not_reassigned(): void
    {
        $this->seed(ProductionLearningSeeder::class);
        $rows = json_decode(file_get_contents(database_path('data/external_biodiversity_references.json')), true)['observations'];
        $row = end($rows);
        $other = Species::where('scientific_name', '!=', $row['scientific_name'])->firstOrFail();
        $record = ExternalSpeciesObservation::create([
            'species_id' => $other->id,
            'source' => 'inaturalist',
            'source_observation_id' => $row['source_observation_id'],
        ]);
        try {
            $this->seed(ProductionBiodiversitySeeder::class);
            $this->fail('Expected conflicting species to reject import.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('Species conflict', $exception->getMessage());
        }
        $this->assertDatabaseCount('external_species_observations', 1);
        $this->assertSame($other->id, $record->fresh()->species_id);
    }
}
