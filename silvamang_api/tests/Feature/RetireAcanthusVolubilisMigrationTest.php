<?php

namespace Tests\Feature;

use App\Models\Species;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RetireAcanthusVolubilisMigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_retirement_hides_the_species_and_preserves_historical_scan_links(): void
    {
        $speciesId = DB::table('species')->insertGetId([
            'scientific_name' => 'Acanthus volubilis',
            'common_name' => 'Climbing mangrove holly',
            'status' => 'active',
            'cnn_supported' => false,
        ]);
        DB::table('mangrove_education')->insert([
            'species_id' => $speciesId,
            'overview' => 'Legacy educational profile.',
            'status' => 'active',
        ]);
        DB::table('mangrove_knowledge')->insert([
            'category' => 'species_information',
            'question' => 'How can I identify Acanthus volubilis?',
            'answer' => 'Legacy knowledge entry.',
            'species_name' => 'Acanthus volubilis',
            'status' => 'active',
        ]);
        $scanId = DB::table('scan_records')->insertGetId([
            'record_code' => 'SC-RETIRED-0001',
            'species_id' => $speciesId,
            'top_scientific_name' => 'Acanthus volubilis',
        ]);
        DB::table('predictions')->insert([
            'scan_record_id' => $scanId,
            'species_id' => $speciesId,
            'rank' => 1,
            'scientific_name' => 'Acanthus volubilis',
            'confidence' => 91.25,
        ]);

        $this->migration()->up();

        $this->assertNull(Species::query()->find($speciesId));
        $this->assertDatabaseHas('species', [
            'id' => $speciesId,
            'scientific_name' => 'Acanthus volubilis',
            'status' => 'inactive',
            'cnn_supported' => false,
        ]);
        $this->assertNotNull(Species::withTrashed()->find($speciesId)?->deleted_at);
        $this->assertDatabaseHas('mangrove_education', [
            'species_id' => $speciesId,
            'status' => 'inactive',
        ]);
        $this->assertDatabaseHas('mangrove_knowledge', [
            'species_name' => 'Acanthus volubilis',
            'status' => 'inactive',
        ]);
        $this->assertDatabaseHas('scan_records', [
            'id' => $scanId,
            'species_id' => $speciesId,
            'top_scientific_name' => 'Acanthus volubilis',
        ]);
        $this->assertDatabaseHas('predictions', [
            'scan_record_id' => $scanId,
            'species_id' => $speciesId,
            'scientific_name' => 'Acanthus volubilis',
        ]);
    }

    public function test_retirement_migration_is_reversible(): void
    {
        $speciesId = DB::table('species')->insertGetId([
            'scientific_name' => 'Acanthus volubilis',
            'status' => 'active',
            'cnn_supported' => false,
        ]);
        DB::table('mangrove_education')->insert([
            'species_id' => $speciesId,
            'status' => 'active',
        ]);
        DB::table('mangrove_knowledge')->insert([
            'category' => 'species_information',
            'question' => 'How can I identify Acanthus volubilis?',
            'answer' => 'Legacy knowledge entry.',
            'species_name' => 'Acanthus volubilis',
            'status' => 'active',
        ]);

        $migration = $this->migration();
        $migration->up();
        $migration->down();

        $this->assertDatabaseHas('species', [
            'id' => $speciesId,
            'status' => 'active',
            'deleted_at' => null,
        ]);
        $this->assertDatabaseHas('mangrove_education', [
            'species_id' => $speciesId,
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('mangrove_knowledge', [
            'species_name' => 'Acanthus volubilis',
            'status' => 'active',
        ]);
    }

    private function migration(): object
    {
        return require database_path(
            'migrations/2026_09_25_000001_retire_acanthus_volubilis.php'
        );
    }
}
