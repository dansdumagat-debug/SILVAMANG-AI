<?php

namespace App\Console\Commands;

use App\Models\Species;
use App\Support\SpeciesTaxonomy;
use Illuminate\Console\Command;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use JsonException;

class SyncCnnSupportedSpecies extends Command
{
    protected $signature = 'species:sync-cnn-support
                            {class-order : Explicit path to the deployed class_order.json}
                            {--apply : Persist the validated support flags}';

    protected $description = 'Validate a deployed CNN class order and synchronize species support flags (dry-run by default).';

    public function handle(): int
    {
        try {
            $classOrderPath = (string) $this->argument('class-order');
            $supportedByKey = $this->loadSupportedSpecies($classOrderPath);

            if ($this->option('apply')) {
                $plan = DB::transaction(function () use ($supportedByKey): array {
                    $plan = $this->buildDatabasePlan($supportedByKey, true);

                    if ($plan['included_ids'] !== []) {
                        Species::query()
                            ->whereIn('id', $plan['included_ids'])
                            ->update(['cnn_supported' => true]);
                    }

                    if ($plan['excluded_ids'] !== []) {
                        Species::query()
                            ->whereIn('id', $plan['excluded_ids'])
                            ->update(['cnn_supported' => false]);
                    }

                    return $plan;
                });

                $this->renderPlan($classOrderPath, $supportedByKey, $plan);
                $this->info('Applied cnn_supported flags in one database transaction.');

                return self::SUCCESS;
            }

            $plan = $this->buildDatabasePlan($supportedByKey);
            $this->renderPlan($classOrderPath, $supportedByKey, $plan);
            $this->warn('Dry run only. Re-run with --apply after the model and class_order.json are deployed together.');

            return self::SUCCESS;
        } catch (InvalidArgumentException $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }
    }

    /**
     * @return array<string, string> Canonical lookup key to canonical scientific name.
     */
    private function loadSupportedSpecies(string $path): array
    {
        if ($path === '' || ! is_file($path) || ! is_readable($path)) {
            throw new InvalidArgumentException("Class order file is not readable: {$path}");
        }

        $contents = file_get_contents($path);

        if ($contents === false) {
            throw new InvalidArgumentException("Unable to read class order file: {$path}");
        }

        try {
            $labels = json_decode($contents, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new InvalidArgumentException(
                "Invalid JSON in class order file: {$exception->getMessage()}",
                previous: $exception
            );
        }

        if (! is_array($labels) || ! array_is_list($labels) || $labels === []) {
            throw new InvalidArgumentException('class_order.json must contain a non-empty JSON list of class labels.');
        }

        $seen = [];
        $supportedByKey = [];

        foreach ($labels as $index => $label) {
            if (! is_string($label) || trim($label) === '') {
                throw new InvalidArgumentException(
                    "Class label at index {$index} must be a non-empty string."
                );
            }

            $canonicalName = SpeciesTaxonomy::canonicalName($label);
            $lookupKey = SpeciesTaxonomy::lookupKey($canonicalName);

            if (array_key_exists($lookupKey, $seen)) {
                throw new InvalidArgumentException(
                    "Duplicate class label after canonicalization [{$canonicalName}]."
                );
            }

            $seen[$lookupKey] = true;

            if ($lookupKey === 'unknown') {
                continue;
            }

            if (! SpeciesTaxonomy::isKnownName($label)) {
                throw new InvalidArgumentException("Unknown class label [{$label}].");
            }

            if (SpeciesTaxonomy::isGuideOnlyName($label)) {
                throw new InvalidArgumentException(
                    "Guide-only species [{$canonicalName}] cannot be enabled as CNN supported."
                );
            }

            $supportedByKey[$lookupKey] = $canonicalName;
        }

        return $supportedByKey;
    }

    /**
     * @param  array<string, string>  $supportedByKey
     * @return array{included_ids: array<int, int>, excluded_ids: array<int, int>}
     */
    private function buildDatabasePlan(array $supportedByKey, bool $lockForUpdate = false): array
    {
        $query = Species::query()->select(['id', 'scientific_name', 'cnn_supported']);

        if ($lockForUpdate) {
            $query->lockForUpdate();
        }

        /** @var Collection<int, Species> $species */
        $species = $query->get();
        $speciesByKey = $species->groupBy(
            fn (Species $item): string => SpeciesTaxonomy::lookupKey($item->scientific_name)
        );
        $includedIds = [];

        foreach ($supportedByKey as $lookupKey => $canonicalName) {
            /** @var Collection<int, Species> $matches */
            $matches = $speciesByKey->get($lookupKey, collect());

            if ($matches->isEmpty()) {
                throw new InvalidArgumentException(
                    "CNN class [{$canonicalName}] has no matching species in the database."
                );
            }

            if ($matches->count() > 1) {
                throw new InvalidArgumentException(
                    "CNN class [{$canonicalName}] matches multiple species records in the database."
                );
            }

            $includedIds[] = (int) $matches->first()->getKey();
        }

        $excludedIds = $species
            ->pluck('id')
            ->map(fn (mixed $id): int => (int) $id)
            ->diff($includedIds)
            ->values()
            ->all();

        return [
            'included_ids' => $includedIds,
            'excluded_ids' => $excludedIds,
        ];
    }

    /**
     * @param  array<string, string>  $supportedByKey
     * @param  array{included_ids: array<int, int>, excluded_ids: array<int, int>}  $plan
     */
    private function renderPlan(string $path, array $supportedByKey, array $plan): void
    {
        $resolvedPath = realpath($path) ?: $path;

        $this->line("Class order: {$resolvedPath}");
        $this->line('Supported database species: '.count($plan['included_ids']));
        $this->line('Unsupported database species: '.count($plan['excluded_ids']));

        foreach ($supportedByKey as $canonicalName) {
            $this->line("  - {$canonicalName}");
        }
    }
}
