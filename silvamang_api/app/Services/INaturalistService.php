<?php

namespace App\Services;

use App\Models\ExternalSpeciesObservation;
use App\Models\Species;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;

class INaturalistService
{
    private const SOURCE = 'inaturalist';

    public function searchSpeciesObservation(string $speciesName): array
    {
        return $this->getSpeciesObservations($speciesName);
    }

    public function getSpeciesPhotos(string $speciesName): array
    {
        $result = $this->getSpeciesObservations($speciesName);
        $result['photos'] = collect($result['observations'] ?? [])
            ->pluck('photo_url')
            ->filter()
            ->values()
            ->all();

        return $result;
    }

    public function getSpeciesObservations(
        string $speciesName,
        ?Species $species = null,
        ?int $limit = null,
        bool $refresh = false
    ): array {
        $cleanName = trim(str_replace('_', ' ', $speciesName));
        $limit = $this->normalizedLimit($limit);

        if ($cleanName === '') {
            return $this->result(
                status: 'error',
                message: 'Species name is required before external references can be loaded.',
                observations: collect(),
                cached: true,
            );
        }

        $species ??= $this->findSpecies($cleanName);
        $cached = $species ? $this->cachedObservations($species, $limit) : collect();

        if (! $refresh && $cached->isNotEmpty()) {
            return $this->result(
                status: 'cached',
                message: 'External biodiversity references loaded from local cache.',
                observations: $cached,
                cached: true,
                species: $species,
            );
        }

        $apiResult = $this->fetchObservations($cleanName, $limit);

        if (($apiResult['status'] ?? 'error') !== 'ok') {
            return $this->result(
                status: $cached->isNotEmpty() ? 'cached_unavailable' : 'error',
                message: $cached->isNotEmpty()
                    ? 'iNaturalist is unavailable. Showing cached biodiversity references.'
                    : ($apiResult['message'] ?? 'iNaturalist biodiversity references are unavailable.'),
                observations: $cached,
                cached: true,
                species: $species,
            );
        }

        if (! $species) {
            return $this->result(
                status: 'uncached',
                message: 'External biodiversity references found, but this species is not in the local species table.',
                observations: collect(),
                cached: false,
                species: null,
            );
        }

        $saved = $this->cacheObservations($species, $apiResult['results'] ?? []);
        $records = $this->cachedObservations($species, $limit);

        return $this->result(
            status: 'synced',
            message: "External biodiversity references synced from iNaturalist. {$saved} record(s) cached.",
            observations: $records,
            cached: false,
            species: $species,
            importedCount: $saved,
        );
    }

    /**
     * @param  array<int, array<string, mixed>>  $observations
     */
    private function cacheObservations(Species $species, array $observations): int
    {
        $saved = 0;

        foreach ($observations as $observation) {
            $sourceId = Arr::get($observation, 'id');
            if (! $sourceId) {
                continue;
            }

            ExternalSpeciesObservation::updateOrCreate(
                [
                    'source' => self::SOURCE,
                    'source_observation_id' => (string) $sourceId,
                ],
                [
                    'species_id' => $species->id,
                    'photo_url' => $this->photoUrl($observation),
                    'observer' => $this->observerName($observation),
                    'location' => $this->locationName($observation),
                    'latitude' => $this->latitude($observation),
                    'longitude' => $this->longitude($observation),
                    'observed_date' => $this->observedDate($observation),
                    'quality_grade' => Arr::get($observation, 'quality_grade'),
                ],
            );

            $saved++;
        }

        return $saved;
    }

    private function fetchObservations(string $speciesName, int $limit): array
    {
        try {
            $response = Http::acceptJson()
                ->timeout((int) config('services.inaturalist.timeout', 15))
                ->get($this->baseUrl() . '/observations', [
                    'taxon_name' => $speciesName,
                    'quality_grade' => 'research',
                    'photos' => 'true',
                    'geo' => 'true',
                    'per_page' => $limit,
                    'order' => 'desc',
                    'order_by' => 'observed_on',
                ]);
        } catch (\Throwable $exception) {
            report($exception);

            return [
                'status' => 'error',
                'message' => 'Unable to connect to iNaturalist biodiversity references.',
                'results' => [],
            ];
        }

        if (! $response->successful()) {
            return [
                'status' => 'error',
                'message' => "iNaturalist returned HTTP {$response->status()}.",
                'results' => [],
            ];
        }

        $results = $response->json('results');

        return [
            'status' => 'ok',
            'message' => 'iNaturalist biodiversity references retrieved.',
            'results' => is_array($results) ? $results : [],
        ];
    }

    private function cachedObservations(Species $species, int $limit): EloquentCollection
    {
        return ExternalSpeciesObservation::query()
            ->where('species_id', $species->id)
            ->where('source', self::SOURCE)
            ->latest('observed_date')
            ->latest()
            ->limit($limit)
            ->get();
    }

    private function findSpecies(string $speciesName): ?Species
    {
        $normalizedName = strtolower($speciesName);

        return Species::query()
            ->whereRaw('LOWER(scientific_name) = ?', [$normalizedName])
            ->orWhereRaw('LOWER(common_name) = ?', [$normalizedName])
            ->first();
    }

    private function normalizedLimit(?int $limit): int
    {
        $default = (int) config('services.inaturalist.per_page', 8);
        $limit ??= $default;

        return max(1, min($limit, 20));
    }

    private function photoUrl(array $observation): ?string
    {
        $url = Arr::get($observation, 'photos.0.url')
            ?: Arr::get($observation, 'photos.0.photo_url')
            ?: Arr::get($observation, 'taxon.default_photo.medium_url')
            ?: Arr::get($observation, 'taxon.default_photo.square_url');

        return is_string($url) && $url !== ''
            ? str_replace('/square.', '/medium.', $url)
            : null;
    }

    private function observerName(array $observation): ?string
    {
        $name = Arr::get($observation, 'user.name') ?: Arr::get($observation, 'user.login');

        return is_string($name) && trim($name) !== '' ? trim($name) : null;
    }

    private function locationName(array $observation): ?string
    {
        $location = Arr::get($observation, 'place_guess') ?: Arr::get($observation, 'location');

        return is_string($location) && trim($location) !== '' ? trim($location) : null;
    }

    private function latitude(array $observation): ?float
    {
        $coordinates = Arr::get($observation, 'geojson.coordinates');
        if (is_array($coordinates) && isset($coordinates[1]) && is_numeric($coordinates[1])) {
            return (float) $coordinates[1];
        }

        $location = Arr::get($observation, 'location');
        if (! is_string($location) || ! str_contains($location, ',')) {
            return null;
        }

        [$latitude] = array_map('trim', explode(',', $location, 2));

        return is_numeric($latitude) ? (float) $latitude : null;
    }

    private function longitude(array $observation): ?float
    {
        $coordinates = Arr::get($observation, 'geojson.coordinates');
        if (is_array($coordinates) && isset($coordinates[0]) && is_numeric($coordinates[0])) {
            return (float) $coordinates[0];
        }

        $location = Arr::get($observation, 'location');
        if (! is_string($location) || ! str_contains($location, ',')) {
            return null;
        }

        [, $longitude] = array_map('trim', explode(',', $location, 2));

        return is_numeric($longitude) ? (float) $longitude : null;
    }

    private function observedDate(array $observation): ?string
    {
        $date = Arr::get($observation, 'observed_on') ?: Arr::get($observation, 'time_observed_at');
        if (! is_string($date) || trim($date) === '') {
            return null;
        }

        try {
            return Carbon::parse($date)->toDateString();
        } catch (\Throwable) {
            return null;
        }
    }

    private function baseUrl(): string
    {
        return rtrim((string) config('services.inaturalist.base_url', 'https://api.inaturalist.org/v1'), '/');
    }

    private function result(
        string $status,
        string $message,
        Collection|EloquentCollection $observations,
        bool $cached,
        ?Species $species = null,
        int $importedCount = 0
    ): array {
        return [
            'status' => $status,
            'message' => $message,
            'source' => self::SOURCE,
            'species' => $species,
            'observations' => $observations,
            'observation_count' => $observations->count(),
            'photos_count' => $observations->whereNotNull('photo_url')->count(),
            'last_synced_at' => $observations->max('updated_at'),
            'cached' => $cached,
            'imported_count' => $importedCount,
        ];
    }
}
