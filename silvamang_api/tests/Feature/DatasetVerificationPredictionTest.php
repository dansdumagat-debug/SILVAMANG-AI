<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\ScanImage;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DatasetVerificationPredictionTest extends TestCase
{
    use RefreshDatabase;

    public function test_researcher_can_review_and_correct_a_predicted_species_without_changing_the_prediction(): void
    {
        $role = Role::create(['name' => 'researcher', 'display_name' => 'Researcher', 'status' => 'active']);
        $researcher = User::factory()->create();
        $researcher->roles()->attach($role);

        $predicted = Species::create(['scientific_name' => 'Avicennia marina', 'common_name' => 'Grey mangrove']);
        $correct = Species::create(['scientific_name' => 'Rhizophora apiculata', 'common_name' => 'Bakauan lalaki']);
        $scan = ScanRecord::create([
            'record_code' => 'SC-REVIEW-001',
            'user_id' => $researcher->id,
            'species_id' => $predicted->id,
            'top_scientific_name' => $predicted->scientific_name,
            'capture_mode' => 'api_ai_classify',
            'confidence' => 86.5,
        ]);
        $image = ScanImage::create([
            'scan_record_id' => $scan->id,
            'plant_part' => 'leaves',
            'image_path' => 'scans/test-mangrove.jpg',
            'original_filename' => 'mangrove.jpg',
            'dataset_status' => 'pending',
        ]);

        $this->actingAs($researcher)->get(route('admin.dataset-verification.index'))
            ->assertOk()
            ->assertSee('App prediction')
            ->assertSee('Avicennia marina');

        $this->get(route('admin.dataset-verification.show', $image))
            ->assertOk()
            ->assertSee('Prediction confidence')
            ->assertSee('86.5%')
            ->assertSee('Verified / Corrected Species');

        $this->patch(route('admin.dataset-verification.update', $image), [
            'verified_species_id' => $correct->id,
            'verified_plant_part' => 'leaves',
            'dataset_status' => 'verified',
            'image_quality' => 'good',
        ])->assertRedirect();

        $this->assertDatabaseHas('scan_images', [
            'id' => $image->id,
            'verified_species_id' => $correct->id,
            'dataset_status' => 'verified',
        ]);
        $this->assertDatabaseHas('scan_records', [
            'id' => $scan->id,
            'top_scientific_name' => $predicted->scientific_name,
            'species_id' => $predicted->id,
        ]);
        $this->get(route('admin.dataset-verification.show', $image))
            ->assertOk()
            ->assertSee('Avicennia marina')
            ->assertSee('Rhizophora apiculata');
    }
}
