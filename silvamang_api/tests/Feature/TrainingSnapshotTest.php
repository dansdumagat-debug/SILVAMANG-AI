<?php

namespace Tests\Feature;

use App\Models\ScanImage;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class TrainingSnapshotTest extends TestCase
{
    use RefreshDatabase;

    public function test_snapshot_only_contains_reviewed_usable_photos_and_removes_revoked_labels(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        $species = Species::create(['scientific_name' => 'Rhizophora apiculata']);
        $scan = ScanRecord::create(['user_id' => $user->id, 'record_code' => 'TRAIN-1']);
        Storage::disk('public')->put('test.png', base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII='));
        $base = ['scan_record_id' => $scan->id, 'image_path' => 'test.png', 'plant_part' => 'leaves', 'verified_species_id' => $species->id, 'verified_plant_part' => 'leaves', 'verified_by' => $user->id, 'verified_at' => now(), 'image_quality' => 'good'];
        $approved = ScanImage::create($base + ['dataset_status' => 'verified']);
        ScanImage::create($base + ['dataset_status' => 'pending']);
        ScanImage::create($base + ['dataset_status' => 'rejected']);
        ScanImage::create(array_merge($base, ['dataset_status' => 'verified', 'verified_by' => null]));
        ScanImage::create(array_merge($base, ['dataset_status' => 'verified', 'image_quality' => 'reject']));
        ScanImage::create(array_merge($base, ['dataset_status' => 'verified', 'verified_plant_part' => 'full_tree']));
        $this->artisan('dataset:training-snapshot')->assertSuccessful();
        $path = storage_path('app/retraining-feed/manifest.json');
        $data = json_decode(file_get_contents($path), true);
        $this->assertCount(1, $data['images']);
        $this->assertSame('Rhizophora_apiculata', $data['images'][0]['species']);
        $this->assertArrayNotHasKey('user_id', $data['images'][0]);
        $approved->update(['dataset_status' => 'rejected']);
        $this->artisan('dataset:training-snapshot')->assertSuccessful();
        $this->assertSame([], json_decode(file_get_contents($path), true)['images']);
    }
}
