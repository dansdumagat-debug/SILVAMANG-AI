<?php

namespace Tests\Feature;

use App\Models\MangroveEducation;
use App\Models\MangroveKnowledge;
use App\Models\Species;
use App\Models\User;
use Database\Seeders\ProductionLearningSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductionLearningSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_learning_seed_is_repeatable_preserves_edits_and_excludes_demo_data(): void
    {
        $user = User::factory()->create();
        $this->seed(ProductionLearningSeeder::class);
        $this->assertDatabaseCount('species', 29);
        $this->assertDatabaseCount('mangrove_education', 29);
        $this->assertSame(28, Species::where('cnn_supported', true)->count());
        $knowledgeCount = MangroveKnowledge::count();
        $this->assertGreaterThan(19, $knowledgeCount);
        $species = Species::where('scientific_name', 'Rhizophora apiculata')->firstOrFail();
        $species->update(['identification_notes' => 'Locally reviewed notes']);
        $lesson = MangroveEducation::where('species_id', $species->id)->firstOrFail();
        $lesson->update(['overview' => 'Locally reviewed lesson']);
        $knowledge = MangroveKnowledge::where('question', 'What is a mangrove?')->firstOrFail();
        $knowledge->update(['answer' => 'Locally reviewed answer']);

        $this->seed(ProductionLearningSeeder::class);
        $this->assertDatabaseCount('species', 29);
        $this->assertDatabaseCount('mangrove_education', 29);
        $this->assertDatabaseCount('mangrove_knowledge', $knowledgeCount);
        $this->assertSame('Locally reviewed notes', $species->fresh()->identification_notes);
        $this->assertSame('Locally reviewed lesson', $lesson->fresh()->overview);
        $this->assertSame('Locally reviewed answer', $knowledge->fresh()->answer);
        $this->assertDatabaseCount('species_distributions', 0);
        $this->assertDatabaseCount('scan_records', 0);
        $this->assertDatabaseCount('transects', 0);
        $this->assertDatabaseCount('external_species_observations', 0);
        $this->assertDatabaseCount('users', 1);
        $this->assertNotNull($user->fresh());
    }
}
