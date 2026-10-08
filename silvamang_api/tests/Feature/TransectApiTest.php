<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\Role;
use App\Models\ScanRecord;
use App\Models\Transect;
use App\Models\User;
use App\Support\ApiId;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PhpOffice\PhpSpreadsheet\IOFactory;
use Tests\TestCase;

class TransectApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_and_idempotently_sync_a_transect_with_an_observation(): void
    {
        $user = User::factory()->create();
        $scan = $this->scanFor($user, 'SC-TRANSECT-001', 'scan-local-001');
        Sanctum::actingAs($user);

        $payload = $this->payload([ApiId::encode($scan->id)]);
        $created = $this->postJson('/api/transects', $payload)
            ->assertCreated()
            ->assertJsonPath('data.transect_name', 'Coastal Baseline T1')
            ->assertJsonPath('data.mode', 'gps_tracking')
            ->assertJsonPath('data.point_count', 3)
            ->assertJsonPath('data.observation_count', 1)
            ->assertJsonPath('data.direction', 'E')
            ->assertJsonCount(0, 'data.pending_observation_references')
            ->assertJsonPath('data.observations.0.record_code', 'SC-TRANSECT-001');

        $encryptedId = $created->json('data.id');
        $this->assertIsString($encryptedId);
        $this->assertNotSame('1', $encryptedId);
        $this->assertDatabaseCount('transects', 1);
        $this->assertDatabaseCount('transect_points', 3);
        $this->assertDatabaseCount('transect_observations', 1);

        $retried = $this->postJson('/api/transects', $payload)
            ->assertOk();
        $this->assertSame(ApiId::decodeOrFail($encryptedId), ApiId::decodeOrFail($retried->json('data.id')));

        $this->assertDatabaseCount('transects', 1);
        $this->getJson('/api/transects/'.$encryptedId)
            ->assertOk()
            ->assertJsonPath('data.total_distance_m', fn ($distance) => $distance > 20);
    }

    public function test_offline_observation_reference_is_retained_then_resolved_on_retry(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = $this->payload(['scan-not-uploaded-yet']);
        $this->postJson('/api/transects', $payload)
            ->assertCreated()
            ->assertJsonPath('data.observation_count', 0)
            ->assertJsonPath('data.pending_observation_references.0', 'scan-not-uploaded-yet');

        $this->scanFor($user, 'SC-LATE-SYNC', 'scan-not-uploaded-yet');

        $this->postJson('/api/transects', $payload)
            ->assertOk()
            ->assertJsonPath('data.observation_count', 1)
            ->assertJsonCount(0, 'data.pending_observation_references');

        $this->assertDatabaseCount('transects', 1);
        $this->assertDatabaseCount('transect_observations', 1);
    }

    public function test_completed_handoff_preserves_contributors_and_does_not_count_gap_between_sections(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $payload = $this->payload();
        $payload['target_distance_m'] = 100;
        $payload['total_distance_m'] = 100;
        $payload['handoff_sequence'] = 4;
        $payload['status'] = 'completed';
        $payload['contributions'] = [
            ['id' => 'a', 'user_id' => 'u1', 'user_name' => 'One', 'distance_m' => 15,
                'points' => [['latitude' => 14.5, 'longitude' => 120.9]],
                'observations' => [['reference' => 'scan-a', 'scientific_name' => 'Avicennia marina', 'image_path' => '/local/photo.jpg']],
                'recorded_at' => now()->toIso8601String()],
            ['id' => 'b', 'user_id' => 'u2', 'user_name' => 'Two', 'distance_m' => 32, 'recorded_at' => now()->toIso8601String()],
            ['id' => 'c', 'user_id' => 'u3', 'user_name' => 'Three', 'distance_m' => 8, 'recorded_at' => now()->toIso8601String()],
            ['id' => 'd', 'user_id' => ApiId::encode($user->id), 'user_name' => 'Final', 'distance_m' => 45, 'recorded_at' => now()->toIso8601String()],
        ];

        $this->postJson('/api/transects', $payload)
            ->assertCreated()
            ->assertJsonPath('data.total_distance_m', 100)
            ->assertJsonPath('data.target_distance_m', 100)
            ->assertJsonPath('data.contributions.0.observations.0.scientific_name', 'Avicennia marina')
            ->assertJsonPath('data.contributions.3.user_name', 'Final');
        $this->postJson('/api/transects', $payload)->assertOk();
        $this->assertDatabaseCount('transects', 1);
    }

    public function test_regular_users_only_see_and_open_their_own_transects(): void
    {
        $firstUser = User::factory()->create();
        $secondUser = User::factory()->create();

        Sanctum::actingAs($firstUser);
        $firstId = $this->postJson('/api/transects', $this->payload())
            ->assertCreated()
            ->json('data.id');

        Sanctum::actingAs($secondUser);
        $secondPayload = $this->payload();
        $secondPayload['offline_reference'] = 'transect-local-002';
        $secondPayload['transect_name'] = 'Second Researcher T1';
        $this->postJson('/api/transects', $secondPayload)->assertCreated();

        $this->getJson('/api/transects?scope=all')
            ->assertOk()
            ->assertJsonPath('scope', 'mine')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.transect_name', 'Second Researcher T1');
        $this->getJson('/api/transects/'.$firstId)->assertNotFound();

        $firstTransect = Transect::query()->where('user_id', $firstUser->id)->firstOrFail();
        $this->actingAs($secondUser)
            ->get('/admin/transects/'.$firstTransect->id)
            ->assertNotFound();
        $response = $this->actingAs($secondUser)
            ->get('/admin/transects/export-excel?transect_id='.$firstTransect->id)
            ->assertOk();
        $path = $response->baseResponse->getFile()->getPathname();
        $book = IOFactory::load($path);
        $this->assertNull($book->getSheetByName('VEGETATION DATA DAY 1')->getCell('F2')->getValue());
        $this->assertNull($book->getSheetByName('Raw Scans')->getCell('C2')->getValue());
        $book->disconnectWorksheets();
        @unlink($path);

    }

    public function test_authorized_researcher_can_filter_and_export_all_transects(): void
    {
        $role = Role::create([
            'name' => 'researcher',
            'display_name' => 'Researcher',
            'status' => 'active',
        ]);
        $researcher = User::factory()->create();
        $researcher->roles()->attach($role);
        $otherUser = User::factory()->create();

        Sanctum::actingAs($researcher);
        $this->postJson('/api/transects', $this->payload())->assertCreated();

        Sanctum::actingAs($otherUser);
        $payload = $this->payload();
        $payload['offline_reference'] = 'transect-local-other';
        $payload['transect_name'] = 'Community Transect';
        $this->postJson('/api/transects', $payload)->assertCreated();

        Sanctum::actingAs($researcher);
        $this->getJson('/api/transects?scope=all')
            ->assertOk()
            ->assertJsonPath('scope', 'all')
            ->assertJsonCount(2, 'data');

        $this->actingAs($researcher)
            ->get('/admin/transects')
            ->assertOk()
            ->assertSee('Community Transect');
        $this->actingAs($researcher)
            ->get('/admin/transects/export')
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_researcher_exports_vegetation_excel_with_linked_scan_and_formulas(): void
    {
        $role = Role::create([
            'name' => 'researcher',
            'display_name' => 'Researcher',
            'status' => 'active',
        ]);
        $researcher = User::factory()->create();
        $researcher->roles()->attach($role);
        $scan = $this->scanFor($researcher, 'SC-EXPORT-001', 'scan-export-001');
        Measurement::create([
            'scan_record_id' => $scan->id,
            'dbh_cm' => 20,
            'measurement_method' => 'manual_input',
        ]);
        Sanctum::actingAs($researcher);
        $this->postJson('/api/transects', $this->payload(['scan-export-001']))->assertCreated();

        $response = $this->actingAs($researcher)
            ->get('/admin/transects/export-excel?plot_area_m2=100')
            ->assertOk()
            ->assertHeader('content-type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        $path = $response->baseResponse->getFile()->getPathname();
        $book = IOFactory::load($path);
        $sheet = $book->getSheetByName('VEGETATION DATA DAY 1');
        $this->assertNotNull($sheet);
        $this->assertSame('Date', (string) $sheet->getCell('A1')->getValue());
        $this->assertSame('Rhizophora apiculata', $sheet->getCell('F2')->getValue());
        $this->assertSame('SC-EXPORT-001', $book->getSheetByName('Raw Scans')->getCell('C2')->getValue());
        $this->assertSame(20.0, $book->getSheetByName('Raw Scans')->getCell('H2')->getValue());
        $this->assertNull($sheet->getCell('J2')->getValue()); // No measured girth on a legacy DBH-only record.
        $this->assertEqualsWithDelta(100, $sheet->getCell('I2')->getCalculatedValue(), 0.0001);
        foreach (['K', 'L', 'M', 'N', 'P', 'Q'] as $column) {
            $this->assertSame('f', $sheet->getCell($column.'2')->getDataType());
            $this->assertSame('', $sheet->getCell($column.'2')->getCalculatedValue());
        }
        $this->assertNull($sheet->getCell('R2')->getValue());
        $this->assertEquals(3.4, $book->getSheetByName('Raw Scans')->getCell('J2')->getValue());
        $book->disconnectWorksheets();
        @unlink($path);

        $withoutArea = $this->actingAs($researcher)
            ->get('/admin/transects/export-excel')
            ->assertOk();
        $blankAreaPath = $withoutArea->baseResponse->getFile()->getPathname();
        $blankAreaBook = IOFactory::load($blankAreaPath);
        $this->assertSame('', $blankAreaBook->getSheetByName('VEGETATION DATA DAY 1')->getCell('I2')->getCalculatedValue());
        $blankAreaBook->disconnectWorksheets();
        @unlink($blankAreaPath);
    }

    public function test_survey_details_save_and_export_with_readable_formats(): void
    {
        $role = Role::create(['name' => 'researcher', 'display_name' => 'Researcher', 'status' => 'active']);
        $user = User::factory()->create();
        $user->roles()->attach($role);
        $scan = $this->scanFor($user, 'SURVEY-EXPORT', 'survey-export');
        Measurement::create(['scan_record_id' => $scan->id, 'gbh_cm' => 2, 'measurement_method' => 'manual_input']);
        $data = ['survey_location' => 'Inside', 'ecological_category' => 'Seedling', 'count_mg' => 41,
            'substrate' => 'Muddy', 'associated_flora' => 'Recorded flora', 'associated_fauna' => 'Recorded fauna',
            'anthropogenic_activity' => 'Fishing', 'impact' => 'Observed impact', 'other_observations' => 'Field notes'];
        $this->actingAs($user)->patch('/admin/scan-records/'.$scan->id.'/survey', $data)->assertRedirect()->assertSessionHasNoErrors();
        $this->assertSame('Healthy mature tree.', $scan->fresh()->notes);
        $this->assertSame(41, $scan->fresh()->count_mg);
        $this->actingAs($user)->patch('/admin/scan-records/'.$scan->id.'/survey', ['count_mg' => 0])->assertSessionHasErrors('count_mg');
        Sanctum::actingAs($user);
        $this->postJson('/api/transects', $this->payload(['survey-export']))->assertCreated();
        $response = $this->actingAs($user)->get('/admin/transects/export-excel?plot_area_m2=100')->assertOk();
        $path = $response->baseResponse->getFile()->getPathname();
        $book = IOFactory::load($path);
        $sheet = $book->getSheetByName('VEGETATION DATA DAY 1');
        foreach (['C2' => 'Inside', 'G2' => 'Seedling', 'H2' => 41, 'T2' => 'Muddy', 'U2' => 'Recorded flora',
            'V2' => 'Recorded fauna', 'W2' => 'Fishing', 'X2' => 'Observed impact', 'Y2' => 'Field notes'] as $cell => $value) {
            $this->assertEquals($value, $sheet->getCell($cell)->getValue());
        }
        $this->assertEquals(4100, $sheet->getCell('I2')->getCalculatedValue());
        $this->assertEqualsWithDelta(2 / pi() / 100, $sheet->getCell('L2')->getCalculatedValue(), 0.00000001);
        $this->assertNotSame('0.0000', $sheet->getCell('M2')->getFormattedValue());
        $this->assertSame('0', $sheet->getStyle('H2')->getNumberFormat()->getFormatCode());
        $this->assertFalse($sheet->getStyle('F2')->getFont()->getBold());
        $this->assertTrue($sheet->getStyle('F2')->getFont()->getItalic());
        $this->assertGreaterThanOrEqual(30, $sheet->getColumnDimension('F')->getWidth());
        $book->disconnectWorksheets();
        @unlink($path);
    }

    private function payload(array $observationReferences = []): array
    {
        return [
            'transect_name' => 'Coastal Baseline T1',
            'location_name' => 'San Roque Mangrove Stand',
            'description' => 'GPS-assisted field documentation transect.',
            'mode' => 'gps_tracking',
            'status' => 'completed',
            'offline_reference' => 'transect-local-001',
            'recorded_at' => '2026-09-15T08:30:00+08:00',
            'points' => [
                ['latitude' => 10.3347000, 'longitude' => 125.0750000, 'accuracy_m' => 4.2],
                ['latitude' => 10.3347000, 'longitude' => 125.0751000, 'accuracy_m' => 4.8],
                ['latitude' => 10.3347000, 'longitude' => 125.0752000, 'accuracy_m' => 5.1],
            ],
            'observation_references' => $observationReferences,
        ];
    }

    private function scanFor(User $user, string $recordCode, string $offlineReference): ScanRecord
    {
        return ScanRecord::create([
            'record_code' => $recordCode,
            'user_id' => $user->id,
            'top_scientific_name' => 'Rhizophora apiculata',
            'top_common_name' => 'Bakawan lalaki',
            'latitude' => 10.3347,
            'longitude' => 125.0751,
            'height_m' => 5.2,
            'canopy_width_m' => 3.4,
            'notes' => 'Healthy mature tree.',
            'offline_reference' => $offlineReference,
            'captured_at' => now(),
        ]);
    }
}
