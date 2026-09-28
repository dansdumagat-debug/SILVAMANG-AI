<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AegicerasFloridumGuideOnlyMigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_existing_species_is_kept_active_but_cnn_support_is_disabled(): void
    {
        $speciesId = DB::table('species')->insertGetId([
            'scientific_name' => 'Aegiceras floridum',
            'common_name' => 'Flowering mangrove',
            'status' => 'active',
            'cnn_supported' => true,
        ]);
        DB::table('mangrove_education')->insert([
            'species_id' => $speciesId,
            'overview' => 'Educational field guide entry.',
            'status' => 'active',
        ]);

        $this->migration()->up();

        $this->assertDatabaseHas('species', [
            'id' => $speciesId,
            'scientific_name' => 'Aegiceras floridum',
            'status' => 'active',
            'cnn_supported' => false,
            'deleted_at' => null,
        ]);
        $this->assertDatabaseHas('mangrove_education', [
            'species_id' => $speciesId,
            'status' => 'active',
        ]);
    }

    private function migration(): object
    {
        return require database_path(
            'migrations/2026_09_25_000002_enforce_aegiceras_floridum_guide_only.php'
        );
    }
}
