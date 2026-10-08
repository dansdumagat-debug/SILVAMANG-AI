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

    public function test_export_date_uses_philippine_capture_time_then_record_creation_time(): void
    {
        $scan = new ScanRecord();
        $scan->captured_at = '2026-10-08 17:30:00';
        $scan->created_at = '2026-10-10 00:00:00';
        $this->assertSame('2026-10-09 01:30', VegetationWorkbookExportService::observationDate($scan)->format('Y-m-d H:i'));
        $this->assertSame('17:30', $scan->captured_at->format('H:i'));
        $scan->captured_at = null;
        $this->assertSame('2026-10-10 08:00', VegetationWorkbookExportService::observationDate($scan)->format('Y-m-d H:i'));
        $scan->created_at = null;
        $this->assertNull(VegetationWorkbookExportService::observationDate($scan));
    }

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
            $sheet = $book->getSheetByName('VEGETATION DATA DAY 1');
            $this->assertSame(3, $sheet->getHighestDataRow('B'));
            $this->assertSame('Recorder A', $sheet->getCell('B2')->getValue());
            $this->assertSame('Recorder B', $sheet->getCell('B3')->getValue());
            $this->assertEquals(174, $sheet->getCell('J2')->getValue());
            $this->assertEquals(1.74, $sheet->getCell('K2')->getCalculatedValue());
            $this->assertEqualsWithDelta(174 / pi() / 100, $sheet->getCell('L2')->getCalculatedValue(), .000001);
            $this->assertSame('f', $sheet->getCell('L2')->getDataType());
            $this->assertSame('', $sheet->getCell('L3')->getCalculatedValue());
            $this->assertEqualsWithDelta(pi() * (174 / pi() / 200) ** 2, $sheet->getCell('M2')->getCalculatedValue(), .000001);
            $this->assertEquals(4, $sheet->getCell('R2')->getValue());
            $this->assertEquals(3.5, $sheet->getCell('S2')->getValue());
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

    public function test_export_filter_uses_field_numbers_and_preserves_record_ids(): void
    {
        $role = \App\Models\Role::create(['name' => 'admin', 'display_name' => 'Admin', 'status' => 'active']);
        $admin = User::factory()->create();
        $admin->roles()->attach($role);
        $expected = [];
        foreach ([2, 1, 2, null] as $index => $number) {
            $transect = Transect::create(['user_id' => $admin->id, 'transect_code' => 'INTERNAL-'.$index,
                'transect_name' => 'Survey '.$index, 'transect_number' => $number,
                'start_latitude' => 10, 'start_longitude' => 125, 'end_latitude' => 10.1, 'end_longitude' => 125.1]);
            $scan = ScanRecord::create(['user_id' => $admin->id, 'record_code' => 'FILTER-'.$index]);
            $transect->observations()->attach($scan);
            $expected[$transect->id] = [$number === null ? 'Not recorded' : (string) $number,
                $number === null ? 'unrecorded' : (string) $number, $transect->id.':'.$scan->id];
        }
        $this->actingAs($admin)->get('/admin/transects/export-selection')->assertOk()
            ->assertViewHas('groups', function ($groups) use ($expected) {
                foreach ($groups as $group) {
                    $this->assertSame($expected[$group['transect_id']], [$group['transect'], $group['transect_number'], $group['records']->first()]);
                }
                return $groups->count() === 4;
            });
    }

    public function test_selected_export_deduplicates_records_and_scopes_plot_formulas(): void
    {
        $role = \App\Models\Role::create(['name' => 'admin', 'display_name' => 'Admin', 'status' => 'active']);
        $admin = User::factory()->create();
        $admin->roles()->attach($role);
        $other = User::factory()->create();
        $t = Transect::create(['user_id' => $admin->id, 'transect_code' => 'SELECT-T1', 'transect_name' => 'Shared', 'start_latitude' => 10, 'start_longitude' => 125, 'end_latitude' => 10.1, 'end_longitude' => 125.1]);
        $scans = collect();
        foreach ([$admin, $other, $other] as $i => $user) {
            $scan = ScanRecord::create(['user_id' => $user->id, 'record_code' => 'SELECT-'.$i, 'plot_no' => $i < 2 ? '1' : '2', 'captured_at' => '2026-10-04 10:00:00']);
            Measurement::create(['scan_record_id' => $scan->id, 'gbh_cm' => 174, 'height_m' => 9, 'canopy_1_m' => 5, 'canopy_2_m' => 3.5]);
            $scans->push($scan);
        }
        $t->observations()->sync($scans->pluck('id'));
        $this->actingAs($admin)->get('/admin/transects/export-selection')->assertOk()->assertSee('Add to Export')->assertSee('Selected Export Records');
        $selection = $scans->map(fn ($s) => $t->id.':'.$s->id)->all();
        $response = $this->post('/admin/transects/export-selected', ['selection' => [...$selection, $selection[0]], 'plot_area_m2' => 100])->assertOk();
        $path = $response->baseResponse->getFile()->getPathname();
        try {
            if ($preview = getenv('EXPORT_PREVIEW_PATH')) {
                copy($path, $preview);
            }
            $book = IOFactory::load($path);
            $sheet = $book->getSheetByName('VEGETATION DATA DAY 1');
            $template = IOFactory::load(resource_path('export-templates/mangrove-monitoring.xlsx'));
            $reference = $template->getSheetByName('VEGETATION DATA DAY 1');
            foreach (range('A', 'Y') as $column) {
                $this->assertEquals($column === 'A' ? 23 : $reference->getColumnDimension($column)->getWidth(), $sheet->getColumnDimension($column)->getWidth());
                $this->assertSame((string) $reference->getCell($column.'1')->getValue(), (string) $sheet->getCell($column.'1')->getValue());
                $this->assertSame($reference->getStyle($column.'1')->getFont()->getHashCode(), $sheet->getStyle($column.'1')->getFont()->getHashCode());
            }
            $template->disconnectWorksheets();
            $this->assertSame('October 04, 2026', $sheet->getCell('A2')->getFormattedValue());
            $this->assertSame('Capture date', $book->getSheetByName('Raw Scans')->getCell('T2')->getValue());
            $this->assertNotEmpty($book->getSheetByName('Export Notes')->getCell('B21')->getValue());
            $zip = new \ZipArchive();
            $zip->open($path);
            $calculation = simplexml_load_string($zip->getFromName('xl/workbook.xml'))->calcPr;
            $this->assertSame('auto', (string) $calculation['calcMode']);
            $this->assertSame('1', (string) $calculation['forceFullCalc']);
            $zip->close();
            $basal = pi() * (174 / pi() / 200) ** 2;
            $this->assertEqualsWithDelta(2 * $basal * 100, $sheet->getCell('N2')->getCalculatedValue(), .00001);
            $this->assertEqualsWithDelta($basal * 100, $sheet->getCell('N4')->getCalculatedValue(), .00001);
            $this->assertEqualsWithDelta(2 * $basal * 9 * .5 * 100, $sheet->getCell('Q2')->getCalculatedValue(), .00001);
            $this->assertSame(4, $sheet->getHighestDataRow('B'));
            $this->assertEquals(5, $sheet->getCell('R2')->getValue());
            $this->assertEquals(3.5, $sheet->getCell('S2')->getValue());
            $this->assertSame(' GBH ( cm)', (string) $sheet->getCell('J1')->getValue());
            $this->assertSame('Other Observations', (string) $sheet->getCell('Y1')->getValue());
            $this->assertSame('', $book->getSheetByName('VEGETATION DATA DAY 2')->getCell('B2')->getFormattedValue());
            $this->assertNotNull($book->getSheetByName('IVI'));
            $combined = $book->getSheetByName('VEGETATION DATA ');
            foreach (['I', 'K', 'L', 'M', 'N', 'O', 'Q', 'R', 'U', 'V', 'W'] as $column) {
                $this->assertSame('f', $combined->getCell($column.'2')->getDataType());
            }
            $this->assertEqualsWithDelta(1.75, $combined->getCell('U2')->getCalculatedValue(), .00001);
            $this->assertEqualsWithDelta(3.375, $combined->getCell('V2')->getCalculatedValue(), .00001);
            $this->assertEqualsWithDelta(.7854 * 3.375 ** 2, $combined->getCell('W2')->getCalculatedValue(), .00001);
            $notes = $book->getSheetByName('Export Notes');
            foreach ([null, 0, -1, 'unknown'] as $missingArea) {
                $notes->setCellValue('B19', $missingArea);
                $book->getCalculationEngine()->clearCalculationCache();
                foreach (['I', 'N', 'Q'] as $column) {
                    $this->assertSame('', $sheet->getCell($column.'2')->getCalculatedValue());
                }
            }
            $notes->setCellValue('B19', 200);
            $book->getCalculationEngine()->clearCalculationCache();
            $this->assertEqualsWithDelta(50, $sheet->getCell('I2')->getCalculatedValue(), .00001);
            $this->assertEqualsWithDelta(2 * $basal * 50, $sheet->getCell('N2')->getCalculatedValue(), .00001);
            $sheet->setCellValue('J2', null);
            $book->getCalculationEngine()->clearCalculationCache();
            foreach (['K', 'L', 'M', 'N', 'P', 'Q'] as $column) {
                $this->assertSame('', $sheet->getCell($column.'2')->getCalculatedValue());
            }

            $book->disconnectWorksheets();
        } finally {
            @unlink($path);
        }
        $this->post('/admin/transects/export-selected', ['selection' => [$t->id.':99999999']])->assertStatus(422);
        $this->actingAs($other)->post('/admin/transects/export-selected', ['selection' => [$selection[0]]])->assertForbidden();
    }
}
