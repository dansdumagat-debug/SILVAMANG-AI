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
        'Avicennia alba',
        'Avicennia officinalis',
        'Nypa fruticans',
        'Lumnitzera racemosa',
        'Lumnitzera littorea',
        'Pemphis acidula',
        'Sonneratia ovata',
        'Camptostemon philippinensis',
        'Heritiera littoralis',
        'Xylocarpus moluccensis',
        'Osbornia octodonta',
        'Aegiceras corniculatum',
        'Aegiceras floridum',
        'Bruguiera cylindrica',
        'Bruguiera sexangula',
        'Ceriops zippeliana',
        'Scyphiphora hydrophylacea',
    ];

    public function test_panel_catalog_adds_all_nineteen_missing_species(): void
    {
        $this->seedCatalog();

        $this->assertCount(19, PanelSpeciesCatalog::entries());
        $this->assertSame(29, Species::query()->count());
        $this->assertSame(29, Species::query()->distinct()->count('scientific_name'));
        $this->assertSame(10, Species::query()->where('cnn_supported', true)->count());
        $this->assertSame(19, Species::query()->where('cnn_supported', false)->count());
        $this->assertSame(29, MangroveEducation::query()->count());

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
            19,
            MangroveKnowledge::query()->whereIn('species_name', $panelNames)->count()
        );
        $this->assertDatabaseMissing('species', [
            'scientific_name' => 'Avicennia marina var. rumphiana',
        ]);
        $this->assertDatabaseMissing('species', [
            'scientific_name' => 'Xylocarpus rumphii',
        ]);
        $this->assertDatabaseHas('species', [
            'scientific_name' => 'Avicennia rumphiana',
            'conservation_status' => 'Vulnerable',
            'cnn_supported' => true,
        ]);
        $this->assertDatabaseHas('species', [
            'scientific_name' => 'Xylocarpus moluccensis',
            'cnn_supported' => false,
        ]);
        $this->assertDatabaseHas('species', [
            'scientific_name' => 'Aegiceras floridum',
            'status' => 'active',
            'cnn_supported' => false,
        ]);

        $aegicerasFloridum = Species::query()
            ->where('scientific_name', 'Aegiceras floridum')
            ->firstOrFail();
        $this->assertDatabaseHas('mangrove_education', [
            'species_id' => $aegicerasFloridum->id,
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('mangrove_knowledge', [
            'species_name' => 'Aegiceras floridum',
            'status' => 'active',
        ]);

        $this->seed(PanelSpeciesSeeder::class);
        $this->seed(PanelSpeciesEducationSeeder::class);
        $this->seed(PanelMangroveKnowledgeSeeder::class);

        $this->assertSame(29, Species::query()->count());
        $this->assertSame(29, MangroveEducation::query()->count());
        $this->assertSame(
            19,
            MangroveKnowledge::query()->whereIn('species_name', $panelNames)->count()
        );
    }

    public function test_legacy_species_names_find_the_canonical_api_records(): void
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

        $this->getJson('/api/species?search=Xylocarpus%20rumphii')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.scientific_name', 'Xylocarpus moluccensis');

        $this->getJson('/api/mangrove-education?species_name=Xylocarpus_rumphii')
            ->assertOk()
            ->assertJsonPath('data.scientific_name', 'Xylocarpus moluccensis');
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
