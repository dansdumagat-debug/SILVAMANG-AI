<?php

namespace Tests\Feature;

use App\Models\MangroveEducation;
use App\Models\MangroveKnowledge;
use App\Models\Species;
use App\Support\SpeciesTaxonomy;
use Database\Seeders\MangroveEducationSeeder;
use Database\Seeders\MangroveKnowledgeSeeder;
use Database\Seeders\PanelMangroveKnowledgeSeeder;
use Database\Seeders\PanelSpeciesEducationSeeder;
use Database\Seeders\PanelSpeciesSeeder;
use Database\Seeders\SpeciesSeeder;
use Database\Seeders\Support\PanelSpeciesCatalog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PanelSpeciesCatalogTest extends TestCase
{
    use RefreshDatabase;

    private const NEW_NAMES = [
        'Acanthus ebracteatus',
        'Acanthus ilicifolius',
        'Acanthus volubilis',
        'Avicennia alba',
        'Avicennia officinalis',
        'Nypa fruticans',
        'Lumnitzera racemosa',
        'Lumnitzera littorea',
        'Pemphis acidula',
        'Sonneratia ovata',
        'Camptostemon philippinensis',
        'Heritiera littoralis',
        'Xylocarpus rumphii',
        'Osbornia octodonta',
        'Aegiceras corniculatum',
        'Aegiceras floridum',
        'Bruguiera cylindrica',
        'Bruguiera sexangula',
        'Ceriops zippeliana',
        'Scyphiphora hydrophylacea',
    ];

    public function test_panel_catalog_adds_all_twenty_missing_species(): void
    {
        $this->seedCatalog();

        $this->assertCount(20, PanelSpeciesCatalog::entries());
        $this->assertSame(30, Species::query()->count());
        $this->assertSame(30, Species::query()->distinct()->count('scientific_name'));
        $this->assertSame(10, Species::query()->where('cnn_supported', true)->count());
        $this->assertSame(20, Species::query()->where('cnn_supported', false)->count());
        $this->assertSame(30, MangroveEducation::query()->count());

        foreach (self::NEW_NAMES as $requestedName) {
            $canonical = SpeciesTaxonomy::canonicalName($requestedName);
            $this->assertSame(
                1,
                Species::query()->where('scientific_name', $canonical)->count(),
                "Expected one catalog record for {$requestedName} as {$canonical}."
            );
        }

        $panelNames = collect(PanelSpeciesCatalog::entries())->pluck('scientific_name');
        $this->assertSame(
            20,
            MangroveKnowledge::query()->whereIn('species_name', $panelNames)->count()
        );
        $this->assertDatabaseMissing('species', [
            'scientific_name' => 'Avicennia marina var. rumphiana',
        ]);
        $this->assertDatabaseMissing('species', [
            'scientific_name' => 'Xylocarpus moluccensis',
        ]);
        $this->assertDatabaseHas('species', [
            'scientific_name' => 'Avicennia rumphiana',
            'conservation_status' => 'Vulnerable',
            'cnn_supported' => true,
        ]);
        $this->assertDatabaseHas('species', [
            'scientific_name' => 'Xylocarpus rumphii',
            'cnn_supported' => false,
        ]);

        $this->seed(PanelSpeciesSeeder::class);
        $this->seed(PanelSpeciesEducationSeeder::class);
        $this->seed(PanelMangroveKnowledgeSeeder::class);

        $this->assertSame(30, Species::query()->count());
        $this->assertSame(30, MangroveEducation::query()->count());
        $this->assertSame(
            20,
            MangroveKnowledge::query()->whereIn('species_name', $panelNames)->count()
        );
    }

    public function test_legacy_avicennia_name_finds_the_canonical_api_record(): void
    {
        $this->seedCatalog();

        $this->getJson('/api/species?search=Avicennia%20marina%20var.%20rumphiana')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.scientific_name', 'Avicennia rumphiana');

        $this->getJson('/api/mangrove-education?species_name=Avicennia_marina_var_rumphiana')
            ->assertOk()
            ->assertJsonPath('data.scientific_name', 'Avicennia rumphiana')
            ->assertJsonPath('data.cnn_supported', true);

        $this->getJson('/api/species?search=Xylocarpus%20moluccensis')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.scientific_name', 'Xylocarpus rumphii');
    }

    private function seedCatalog(): void
    {
        $this->seed(SpeciesSeeder::class);
        $this->seed(PanelSpeciesSeeder::class);
        $this->seed(MangroveEducationSeeder::class);
        $this->seed(PanelSpeciesEducationSeeder::class);
        $this->seed(MangroveKnowledgeSeeder::class);
        $this->seed(PanelMangroveKnowledgeSeeder::class);
    }
}
