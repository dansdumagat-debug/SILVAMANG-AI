<?php

namespace Tests\Feature;

use App\Models\LocationValidation;
use App\Models\Role;
use App\Models\ScanRecord;
use App\Models\User;
use App\Support\ApiId;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ScanMapTest extends TestCase
{
    use RefreshDatabase;

    public function test_mobile_map_feed_can_switch_between_my_scans_and_all_scans(): void
    {
        $currentUser = User::factory()->create();
        $otherUser = User::factory()->create();

        $mine = $this->scanFor($currentUser, 'SC-MINE-001', 10.31, 125.01);
        $other = $this->scanFor($otherUser, 'SC-OTHER-001', 10.42, 125.12);
        ScanRecord::create([
            'record_code' => 'SC-NO-PIN-001',
            'user_id' => $otherUser->id,
            'top_scientific_name' => 'Avicennia marina',
        ]);

        Sanctum::actingAs($currentUser);

        $this->getJson('/api/scan-map?scope=mine')
            ->assertOk()
            ->assertJsonPath('scope', 'mine')
            ->assertJsonPath('counts.my_scans', 1)
            ->assertJsonPath('counts.my_pins', 1)
            ->assertJsonPath('counts.all_scans', 3)
            ->assertJsonPath('counts.all_pins', 2)
            ->assertJsonPath('counts.returned_pins', 1)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.record_code', $mine->record_code)
            ->assertJsonPath('data.0.is_mine', true)
            ->assertJsonPath('data.0.can_view_record', true)
            ->assertJsonMissingPath('data.0.notes')
            ->assertJsonMissingPath('data.0.user_email');

        $this->getJson('/api/scan-map?scope=all')
            ->assertOk()
            ->assertJsonPath('scope', 'all')
            ->assertJsonPath('counts.my_scans', 1)
            ->assertJsonPath('counts.my_pins', 1)
            ->assertJsonPath('counts.all_scans', 3)
            ->assertJsonPath('counts.all_pins', 2)
            ->assertJsonPath('counts.returned_pins', 2)
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment([
                'record_code' => $other->record_code,
                'scanner_name' => $otherUser->name,
                'is_mine' => false,
                'can_view_record' => false,
            ]);
    }

    public function test_mobile_web_map_defaults_to_own_records_and_can_show_all_records(): void
    {
        $mobileRole = Role::create([
            'name' => 'mobile_user',
            'display_name' => 'Mobile User',
            'status' => 'active',
        ]);
        $currentUser = User::factory()->create();
        $currentUser->roles()->attach($mobileRole);
        $otherUser = User::factory()->create();

        $this->scanFor($currentUser, 'SC-WEB-MINE', 10.31, 125.01);
        $this->scanFor($otherUser, 'SC-WEB-OTHER', 10.42, 125.12);

        $this->actingAs($currentUser)
            ->get('/admin/my-map')
            ->assertOk()
            ->assertSee('My Scan Map')
            ->assertSee('SC-WEB-MINE')
            ->assertDontSee('SC-WEB-OTHER');

        $this->actingAs($currentUser)
            ->get('/admin/my-map?scope=all')
            ->assertOk()
            ->assertSee('SC-WEB-MINE')
            ->assertSee('SC-WEB-OTHER')
            ->assertDontSee($otherUser->email);
    }

    public function test_mobile_web_dashboard_shows_only_the_signed_in_users_story(): void
    {
        $mobileRole = Role::create([
            'name' => 'mobile_user',
            'display_name' => 'Mobile User',
            'status' => 'active',
        ]);
        $currentUser = User::factory()->create();
        $currentUser->roles()->attach($mobileRole);
        $otherUser = User::factory()->create();

        $this->scanFor($currentUser, 'SC-STORY-MINE', 10.31, 125.01);
        $this->scanFor($otherUser, 'SC-STORY-OTHER', 10.42, 125.12);
        $validatedLocationScan = ScanRecord::create([
            'record_code' => 'SC-STORY-VALIDATED-PIN',
            'user_id' => $currentUser->id,
            'top_scientific_name' => 'Avicennia marina',
            'captured_at' => now(),
        ]);
        LocationValidation::create([
            'scan_record_id' => $validatedLocationScan->id,
            'latitude' => 10.55,
            'longitude' => 125.25,
            'result' => 'match',
            'validated_at' => now(),
        ]);

        $this->actingAs($currentUser)
            ->get('/admin/dashboard')
            ->assertOk()
            ->assertSee('My Field Story')
            ->assertSee('SC-STORY-MINE')
            ->assertSee('SC-STORY-VALIDATED-PIN')
            ->assertDontSee('SC-STORY-OTHER')
            ->assertDontSee($otherUser->email)
            ->assertViewHas('personalStats', fn (array $stats) => $stats['map_pins'] === 2)
            ->assertViewHas('mapPins', fn ($pins) => $pins->count() === 2);
    }

    public function test_mobile_scan_history_cannot_read_another_users_record(): void
    {
        $currentUser = User::factory()->create();
        $otherUser = User::factory()->create();

        $mine = $this->scanFor($currentUser, 'SC-HISTORY-MINE', 10.31, 125.01);
        $other = $this->scanFor($otherUser, 'SC-HISTORY-OTHER', 10.42, 125.12);

        Sanctum::actingAs($currentUser);

        $this->getJson('/api/scan-records')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonFragment(['record_code' => $mine->record_code])
            ->assertJsonMissing(['record_code' => $other->record_code]);

        $this->getJson('/api/scan-records/' . ApiId::encode($other->id))
            ->assertNotFound();

        Sanctum::actingAs($otherUser);

        $this->getJson('/api/scan-records')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonFragment(['record_code' => $other->record_code])
            ->assertJsonMissing(['record_code' => $mine->record_code]);

        $this->getJson('/api/scan-records/' . ApiId::encode($mine->id))
            ->assertNotFound();
    }

    private function scanFor(User $user, string $recordCode, float $latitude, float $longitude): ScanRecord
    {
        return ScanRecord::create([
            'record_code' => $recordCode,
            'user_id' => $user->id,
            'top_scientific_name' => 'Rhizophora apiculata',
            'top_common_name' => 'Red mangrove',
            'confidence' => 91.5,
            'identification_status' => 'completed',
            'validation_status' => 'match',
            'latitude' => $latitude,
            'longitude' => $longitude,
            'barangay' => 'San Roque',
            'captured_at' => now(),
        ]);
    }
}
