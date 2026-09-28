<?php

namespace Tests\Feature;

use App\Models\Species;
use Database\Seeders\DeployedModelSpeciesSeeder;
use Database\Seeders\PanelSpeciesSeeder;
use Database\Seeders\SpeciesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeployedModelSpeciesTest extends TestCase
{
    use RefreshDatabase;

    public function test_deployed_labels_enable_28_species_and_preserve_guide_only_entry(): void
    {
        $this->seed([SpeciesSeeder::class, PanelSpeciesSeeder::class]);
        $species = Species::where('scientific_name', 'Acanthus ebracteatus')->firstOrFail();
        $species->update(['identification_notes' => 'Leaf notes. Knowledge-base species only; not supported by the current 10-class CNN.']);
        $this->seed(DeployedModelSpeciesSeeder::class);
        $this->seed(DeployedModelSpeciesSeeder::class);
        $this->assertSame(29, Species::count());
        $this->assertSame(28, Species::where('cnn_supported', true)->count());
        $this->assertDatabaseHas('species', ['scientific_name' => 'Aegiceras floridum', 'cnn_supported' => false]);
        $this->assertDatabaseMissing('species', ['scientific_name' => 'unknown']);
        $this->assertSame('Leaf notes.', $species->fresh()->identification_notes);
        $this->assertSame(
            json_decode(file_get_contents(base_path('../silvamang_mobile/assets/models/class_order.json')), true),
            json_decode(file_get_contents(resource_path('ai/class_order.json')), true)
        );
    }
}
