<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\ScanRecord;
use App\Models\Transect;
use App\Models\User;
use App\Services\VegetationWorkbookExportService;
use App\Support\ApiId;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use PhpOffice\PhpSpreadsheet\IOFactory;
use Tests\TestCase;

class StructuralMeasurementTest extends TestCase
{
    use RefreshDatabase;

    public function test_migration_is_repeatable_and_backfills_only_missing_legacy_conversions(): void
    {
        $user = User::factory()->create();
        $scan = ScanRecord::create(['user_id' => $user->id, 'record_code' => 'LEGACY']);
        \Illuminate\Support\Facades\DB::table('measurements')->insert([
            'scan_record_id' => $scan->id, 'height_m' => 5.2, 'dbh_cm' => 20, 'canopy_width_m' => 3.4,
        ]);
        $migration = require database_path('migrations/2026_10_02_140000_add_structural_measurements.php');
        $migration->up();
        $migration->up();
        $m = $scan->measurement()->firstOrFail();
        $this->assertEquals(.2, $m->dbh_m);
        $this->assertEqualsWithDelta(pi() * .1 ** 2, (float) $m->basal_area_m2, .000001);
        $this->assertEquals(5.2, $m->height_m);
        $this->assertEquals(3.4, $m->canopy_width_m);
        $this->assertNull($m->gbh_cm);
        $this->assertNull($m->canopy_1_m);
    }

    public function test_api_converts_girth_preserves_height_and_does_not_invent_canopy_width(): void
    {
        $user = User::factory()->create();
        $scan = ScanRecord::create(['user_id' => $user->id, 'record_code' => 'STRUCT-1', 'plot_no' => '1']);
        Sanctum::actingAs($user);
        $payload = ['scan_record_id' => ApiId::encode($scan->id), 'height_m' => 5.2,
            'gbh_cm' => 174, 'canopy_1_m' => 4, 'canopy_2_m' => 3.5, 'measurement_method' => 'manual_input'];
        $this->postJson('/api/measurements', $payload)->assertCreated()
            ->assertJsonPath('data.gbh_cm', 174)->assertJsonPath('data.gbh_m', 1.74)
            ->assertJsonPath('data.dbh_cm', 55.39)->assertJsonPath('data.canopy_width_m', null);
        $this->postJson('/api/measurements', ['scan_record_id' => ApiId::encode($scan->id), 'canopy_2_m' => 3.8])->assertCreated();
        $this->assertDatabaseCount('measurements', 1);
        $m = $scan->measurement()->firstOrFail();
        $this->assertEquals(5.2, $m->height_m);
        $this->assertEquals(4, $m->canopy_1_m);
        $this->assertEquals(3.8, $m->canopy_2_m);
        $this->assertEqualsWithDelta(pi() * (0.5539 / 2) ** 2, (float) $m->basal_area_m2, .000001);
        $this->postJson('/api/measurements', ['scan_record_id' => ApiId::encode($scan->id), 'gbh_cm' => -1])->assertUnprocessable();
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/measurements', $payload)->assertNotFound();
    }

    public function test_export_keeps_two_recorders_one_transect_and_blank_unknown_values(): void
    {
        $a = User::factory()->create(['name' => 'Recorder A']);
        $b = User::factory()->create(['name' => 'Recorder B']);
        $t = Transect::create(['user_id' => $a->id, 'transect_code' => 'T1', 'transect_name' => 'Shared transect', 'start_latitude' => 10.3, 'start_longitude' => 125.1, 'end_latitude' => 10.4, 'end_longitude' => 125.2]);
        $one = ScanRecord::create(['user_id' => $a->id, 'record_code' => 'OBS1', 'plot_no' => '1', 'top_scientific_name' => 'Rhizophora stylosa']);
        $two = ScanRecord::create(['user_id' => $b->id, 'record_code' => 'OBS2', 'plot_no' => '1', 'top_scientific_name' => 'Rhizophora stylosa']);
        $t->observations()->sync([$one->id, $two->id]);
        Measurement::create(['scan_record_id' => $one->id, 'height_m' => 5.2, 'gbh_cm' => 174, 'canopy_1_m' => 4, 'canopy_2_m' => 3.5]);
        $t->load('observations.user', 'observations.measurement', 'observations.species');
        $path = app(VegetationWorkbookExportService::class)->create(collect([$t, $t]));
        try {
            $book = IOFactory::load($path);
            $sheet = $book->getSheetByName('Vegetation Data');
            $this->assertSame(3, $sheet->getHighestDataRow());
            $this->assertSame('Recorder A', $sheet->getCell('B2')->getValue());
            $this->assertSame('Recorder B', $sheet->getCell('B3')->getValue());
            $this->assertEquals(174, $sheet->getCell('J2')->getValue());
            $this->assertEquals(1.74, $sheet->getCell('K2')->getValue());
            $this->assertEquals(55.39, $sheet->getCell('L2')->getValue());
            $this->assertEquals(.5539, $sheet->getCell('M2')->getValue());
            $this->assertEquals(4, $sheet->getCell('S2')->getValue());
            $this->assertEquals(3.5, $sheet->getCell('T2')->getValue());
            $this->assertNull($sheet->getCell('U2')->getValue());
            $this->assertNull($sheet->getCell('J3')->getValue());
            $this->assertNull($sheet->getCell('V2')->getValue());
            $this->assertSame('A2', $sheet->getFreezePane());
            $summary = $book->getSheetByName('Transect Summary');
            $this->assertEquals(2, $summary->getCell('K2')->getValue());
            $this->assertSame('Recorder A; Recorder B', $summary->getCell('M2')->getValue());
            $species = $book->getSheetByName('Species Summary');
            $this->assertEquals(5.2, $species->getCell('G2')->getValue());
            $this->assertNull($species->getCell('L2')->getValue());
            $book->disconnectWorksheets();
        } finally {
            @unlink($path);
        }
    }
}
