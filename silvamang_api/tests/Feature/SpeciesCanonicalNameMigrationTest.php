<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SpeciesCanonicalNameMigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_legacy_names_are_renamed_in_place_and_repeated_string_fields_are_updated(): void
    {
        $xylocarpusId = DB::table('species')->insertGetId([
            'scientific_name' => 'Xylocarpus rumphii',
            'description' => 'A coastal tree historically reported in Philippine guides as Xylocarpus moluccensis.',
            'status' => 'active',
        ]);
        $avicenniaId = DB::table('species')->insertGetId([
            'scientific_name' => 'Avicennia marina var. rumphiana',
            'status' => 'active',
        ]);
        DB::table('species')->insert([
            'scientific_name' => 'Avicennia_rumphiana',
            'status' => 'active',
        ]);
        $scanId = DB::table('scan_records')->insertGetId([
            'record_code' => 'SC-CANONICAL-0001',
            'species_id' => $xylocarpusId,
            'top_scientific_name' => 'Xylocarpus rumphii',
        ]);
        DB::table('predictions')->insert([
            'scan_record_id' => $scanId,
            'species_id' => $xylocarpusId,
            'rank' => 1,
            'scientific_name' => 'Xylocarpus rumphii',
            'confidence' => 96.25,
        ]);
        DB::table('mangrove_knowledge')->insert([
            'category' => 'species_information',
            'question' => 'How can I identify Xylocarpus_rumphii?',
            'answer' => 'A coastal tree historically reported in Philippine guides as Xylocarpus moluccensis.',
            'species_name' => 'Xylocarpus rumphii',
            'related_species' => 'Xylocarpus rumphii, Avicennia_rumphiana',
            'keywords' => 'Xylocarpus_rumphii, mangrove',
        ]);
        DB::table('scan_records')->insert([
            'record_code' => 'SC-CANONICAL-0002',
            'species_id' => $avicenniaId,
            'top_scientific_name' => 'Avicennia_marina_var_rumphiana',
        ]);
        DB::table('scan_records')->insert([
            'record_code' => 'SC-CANONICAL-0003',
            'species_id' => $xylocarpusId,
            'top_scientific_name' => 'Xylocarpus_moluccensis',
        ]);

        $this->runCanonicalNameMigration();

        $this->assertDatabaseHas('species', [
            'id' => $xylocarpusId,
            'scientific_name' => 'Xylocarpus moluccensis',
        ]);
        $this->assertDatabaseMissing('species', ['scientific_name' => 'Xylocarpus rumphii']);
        $this->assertDatabaseHas('scan_records', [
            'id' => $scanId,
            'species_id' => $xylocarpusId,
            'top_scientific_name' => 'Xylocarpus moluccensis',
        ]);
        $this->assertDatabaseHas('predictions', [
            'scan_record_id' => $scanId,
            'species_id' => $xylocarpusId,
            'scientific_name' => 'Xylocarpus moluccensis',
        ]);
        $this->assertDatabaseHas('mangrove_knowledge', [
            'question' => 'How can I identify Xylocarpus moluccensis?',
            'species_name' => 'Xylocarpus moluccensis',
            'related_species' => 'Xylocarpus moluccensis, Avicennia rumphiana',
            'keywords' => 'Xylocarpus moluccensis, mangrove',
        ]);
        $this->assertDatabaseHas('species', [
            'id' => $avicenniaId,
            'scientific_name' => 'Avicennia rumphiana',
        ]);
        $this->assertSame(
            1,
            DB::table('species')->where('scientific_name', 'Avicennia rumphiana')->count()
        );
        $this->assertDatabaseHas('scan_records', [
            'record_code' => 'SC-CANONICAL-0002',
            'top_scientific_name' => 'Avicennia rumphiana',
        ]);
        $this->assertDatabaseHas('scan_records', [
            'record_code' => 'SC-CANONICAL-0003',
            'top_scientific_name' => 'Xylocarpus moluccensis',
        ]);
    }

    public function test_duplicate_species_rows_are_merged_without_losing_relationships_or_education(): void
    {
        $canonicalId = DB::table('species')->insertGetId([
            'scientific_name' => 'Xylocarpus moluccensis',
            'common_name' => 'Canonical common name',
            'status' => 'active',
        ]);
        $legacyId = DB::table('species')->insertGetId([
            'scientific_name' => 'Xylocarpus rumphii',
            'family' => 'Meliaceae',
            'status' => 'active',
        ]);
        DB::table('species_images')->insert([
            'species_id' => $legacyId,
            'image_path' => 'species/xylocarpus-legacy.jpg',
        ]);
        DB::table('mangrove_education')->insert([
            'species_id' => $canonicalId,
            'overview' => 'Canonical overview',
            'physical_characteristics' => json_encode([
                'source' => 'canonical',
                'nested' => ['keep' => true],
            ]),
            'interesting_facts' => json_encode(['Canonical fact']),
            'status' => 'active',
        ]);
        DB::table('mangrove_education')->insert([
            'species_id' => $legacyId,
            'overview' => 'Legacy overview',
            'physical_characteristics' => json_encode([
                'source' => 'legacy',
                'nested' => ['other' => true],
            ]),
            'interesting_facts' => json_encode(['Legacy fact']),
            'status' => 'active',
        ]);

        $this->runCanonicalNameMigration();
        $this->runCanonicalNameMigration();

        $this->assertSame(
            1,
            DB::table('species')->where('scientific_name', 'Xylocarpus moluccensis')->count()
        );
        $this->assertDatabaseMissing('species', ['id' => $legacyId]);
        $this->assertDatabaseHas('species', [
            'id' => $canonicalId,
            'scientific_name' => 'Xylocarpus moluccensis',
            'common_name' => 'Canonical common name',
            'family' => 'Meliaceae',
        ]);
        $this->assertDatabaseHas('species_images', [
            'species_id' => $canonicalId,
            'image_path' => 'species/xylocarpus-legacy.jpg',
        ]);

        $educationRows = DB::table('mangrove_education')
            ->where('species_id', $canonicalId)
            ->get();
        $this->assertCount(1, $educationRows);
        $this->assertStringContainsString('Canonical overview', $educationRows->first()->overview);
        $this->assertStringContainsString('Legacy overview', $educationRows->first()->overview);
        $this->assertEqualsCanonicalizing(
            ['Canonical fact', 'Legacy fact'],
            json_decode($educationRows->first()->interesting_facts, true)
        );
        $physicalCharacteristics = json_decode(
            $educationRows->first()->physical_characteristics,
            true
        );
        $this->assertSame('canonical', $physicalCharacteristics['source']);
        $this->assertTrue($physicalCharacteristics['nested']['keep']);
        $this->assertTrue($physicalCharacteristics['nested']['other']);
    }

    public function test_json_merge_preserves_canonical_raw_data_when_legacy_json_is_invalid_or_differently_shaped(): void
    {
        $migration = $this->canonicalNameMigration();
        $method = new \ReflectionMethod($migration, 'mergeJsonValues');
        $method->setAccessible(true);

        $canonicalList = '["Canonical fact"]';
        $canonicalObject = '{"source":"canonical"}';

        $this->assertSame(
            $canonicalList,
            $method->invoke($migration, $canonicalList, 'not-valid-json')
        );
        $this->assertSame(
            $canonicalObject,
            $method->invoke($migration, $canonicalObject, '["Legacy fact"]')
        );
        $this->assertSame(
            'not-valid-json',
            $method->invoke($migration, null, 'not-valid-json')
        );
    }

    private function runCanonicalNameMigration(): void
    {
        $this->canonicalNameMigration()->up();
    }

    private function canonicalNameMigration(): object
    {
        return require database_path(
            'migrations/2026_09_24_000001_canonicalize_xylocarpus_moluccensis_name.php'
        );
    }
}
