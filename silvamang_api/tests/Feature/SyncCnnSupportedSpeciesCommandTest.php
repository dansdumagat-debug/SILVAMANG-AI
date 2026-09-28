<?php

namespace Tests\Feature;

use App\Models\Species;
use Illuminate\Foundation\Testing\RefreshDatabase;
use JsonException;
use RuntimeException;
use Tests\TestCase;

class SyncCnnSupportedSpeciesCommandTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<int, string> */
    private array $temporaryFiles = [];

    protected function tearDown(): void
    {
        foreach ($this->temporaryFiles as $path) {
            if (is_file($path)) {
                unlink($path);
            }
        }

        parent::tearDown();
    }

    public function test_it_is_a_dry_run_by_default_and_canonicalizes_labels(): void
    {
        $rumphiana = $this->createSpecies('Avicennia rumphiana', false);
        $rhizophora = $this->createSpecies('Rhizophora apiculata', false);
        $excluded = $this->createSpecies('Sonneratia alba', true);
        $classOrder = $this->writeClassOrder([
            'Avicennia_marina_var_rumphiana',
            'Rhizophora_apiculata',
            'unknown',
        ]);

        $this->artisan('species:sync-cnn-support', ['class-order' => $classOrder])
            ->expectsOutputToContain('Supported database species: 2')
            ->expectsOutputToContain('Unsupported database species: 1')
            ->expectsOutputToContain('Dry run only.')
            ->assertSuccessful();

        $this->assertFalse((bool) $rumphiana->fresh()->cnn_supported);
        $this->assertFalse((bool) $rhizophora->fresh()->cnn_supported);
        $this->assertTrue((bool) $excluded->fresh()->cnn_supported);
    }

    public function test_apply_sets_included_true_and_excluded_false_while_ignoring_unknown(): void
    {
        $included = $this->createSpecies('Avicennia marina', false);
        $legacyAliasTarget = $this->createSpecies('Xylocarpus moluccensis', false);
        $excluded = $this->createSpecies('Rhizophora apiculata', true);
        $classOrder = $this->writeClassOrder([
            'Avicennia_marina',
            'Xylocarpus_rumphii',
            'unknown',
        ]);

        $this->artisan('species:sync-cnn-support', [
            'class-order' => $classOrder,
            '--apply' => true,
        ])
            ->expectsOutputToContain('Applied cnn_supported flags in one database transaction.')
            ->assertSuccessful();

        $this->assertTrue((bool) $included->fresh()->cnn_supported);
        $this->assertTrue((bool) $legacyAliasTarget->fresh()->cnn_supported);
        $this->assertFalse((bool) $excluded->fresh()->cnn_supported);
    }

    public function test_it_rejects_duplicate_labels_after_canonicalization_without_writing(): void
    {
        $species = $this->createSpecies('Avicennia rumphiana', false);
        $classOrder = $this->writeClassOrder([
            'Avicennia_rumphiana',
            'Avicennia_marina_var_rumphiana',
        ]);

        $this->artisan('species:sync-cnn-support', [
            'class-order' => $classOrder,
            '--apply' => true,
        ])
            ->expectsOutputToContain('Duplicate class label after canonicalization [Avicennia rumphiana].')
            ->assertExitCode(1);

        $this->assertFalse((bool) $species->fresh()->cnn_supported);
    }

    public function test_it_rejects_labels_outside_the_known_taxonomy_without_writing(): void
    {
        $species = $this->createSpecies('Avicennia marina', false);
        $classOrder = $this->writeClassOrder([
            'Avicennia_marina',
            'Laguncularia_racemosa',
        ]);

        $this->artisan('species:sync-cnn-support', [
            'class-order' => $classOrder,
            '--apply' => true,
        ])
            ->expectsOutputToContain('Unknown class label [Laguncularia_racemosa].')
            ->assertExitCode(1);

        $this->assertFalse((bool) $species->fresh()->cnn_supported);
    }

    public function test_it_rejects_a_known_class_missing_from_the_database_without_writing(): void
    {
        $excluded = $this->createSpecies('Sonneratia alba', true);
        $classOrder = $this->writeClassOrder([
            'Avicennia_marina',
            'unknown',
        ]);

        $this->artisan('species:sync-cnn-support', [
            'class-order' => $classOrder,
            '--apply' => true,
        ])
            ->expectsOutputToContain('CNN class [Avicennia marina] has no matching species in the database.')
            ->assertExitCode(1);

        $this->assertTrue((bool) $excluded->fresh()->cnn_supported);
    }

    public function test_it_rejects_guide_only_species_without_enabling_support(): void
    {
        $guideOnly = $this->createSpecies('Aegiceras floridum', false);
        $classOrder = $this->writeClassOrder([
            'Aegiceras_floridum',
            'unknown',
        ]);

        $this->artisan('species:sync-cnn-support', [
            'class-order' => $classOrder,
            '--apply' => true,
        ])
            ->expectsOutputToContain(
                'Guide-only species [Aegiceras floridum] cannot be enabled as CNN supported.'
            )
            ->assertExitCode(1);

        $this->assertFalse((bool) $guideOnly->fresh()->cnn_supported);
    }

    public function test_it_rejects_malformed_class_order_json(): void
    {
        $classOrder = $this->writeRawClassOrder('{not-json');

        $this->artisan('species:sync-cnn-support', ['class-order' => $classOrder])
            ->expectsOutputToContain('Invalid JSON in class order file:')
            ->assertExitCode(1);
    }

    private function createSpecies(string $scientificName, bool $cnnSupported): Species
    {
        return Species::query()->create([
            'scientific_name' => $scientificName,
            'cnn_supported' => $cnnSupported,
        ]);
    }

    /**
     * @param  array<int, mixed>  $labels
     *
     * @throws JsonException
     */
    private function writeClassOrder(array $labels): string
    {
        return $this->writeRawClassOrder(json_encode($labels, JSON_THROW_ON_ERROR));
    }

    private function writeRawClassOrder(string $contents): string
    {
        $path = tempnam(sys_get_temp_dir(), 'silvamang-class-order-');

        if ($path === false || file_put_contents($path, $contents) === false) {
            throw new RuntimeException('Unable to create a temporary class order file.');
        }

        $this->temporaryFiles[] = $path;

        return $path;
    }
}
