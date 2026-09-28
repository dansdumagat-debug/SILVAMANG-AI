<?php

namespace Tests\Feature;

use App\Models\ScanRecord;
use App\Models\User;
use App\Support\ApiId;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PersistentScanStorageTest extends TestCase
{
    use RefreshDatabase;

    public function test_uploaded_scan_image_uses_the_configured_public_storage_root(): void
    {
        $root = sys_get_temp_dir().'/silvamang-scan-storage-'.Str::random(12);
        config(['filesystems.disks.public.root' => $root]);

        try {
            $user = User::factory()->create();
            $scan = ScanRecord::create([
                'record_code' => 'SC-PERSISTENCE-001',
                'user_id' => $user->id,
                'capture_mode' => 'manual',
            ]);
            Sanctum::actingAs($user);

            $response = $this->post('/api/scan-images', [
                'scan_record_id' => ApiId::encode($scan->id),
                'plant_part' => 'leaves',
                'image' => UploadedFile::fake()->image('leaves.jpg'),
            ], ['Accept' => 'application/json'])->assertCreated();

            $path = $response->json('data.image_path');
            $this->assertIsString($path);
            $this->assertFileExists($root.'/'.$path);
            $this->assertDatabaseHas('scan_images', [
                'scan_record_id' => $scan->id,
                'image_path' => $path,
            ]);
        } finally {
            Storage::disk('public')->deleteDirectory('scan-images');
            if (is_dir($root)) {
                rmdir($root);
            }
        }
    }
}
