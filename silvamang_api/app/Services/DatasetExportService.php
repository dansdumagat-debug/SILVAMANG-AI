<?php

namespace App\Services;

use App\Models\ScanImage;
use App\Models\Species;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class DatasetExportService
{
    private const MANIFEST_COLUMNS = [
        'image_id',
        'file_path',
        'species_scientific_name',
        'common_name',
        'plant_part',
        'source',
        'photographer',
        'permission_status',
        'province',
        'municipality',
        'barangay',
        'latitude',
        'longitude',
        'date_captured',
        'image_quality',
        'split',
        'annotation_status',
        'notes',
    ];

    public function exportVerifiedImages(): array
    {
        $summary = [
            'exported_count' => 0,
            'skipped_count' => 0,
            'errors' => [],
        ];

        $scanImages = ScanImage::query()
            ->with(['verifiedSpecies', 'scanRecord.user', 'verifier'])
            ->where('dataset_status', 'verified')
            ->whereNotNull('verified_species_id')
            ->whereNotNull('verified_plant_part')
            ->whereIn('image_quality', ['good', 'acceptable'])
            ->whereNull('dataset_exported_at')
            ->get();

        foreach ($scanImages as $scanImage) {
            try {
                if (! $scanImage->verifiedSpecies || ! $scanImage->image_path) {
                    $summary['skipped_count']++;
                    continue;
                }

                if (! Storage::disk('public')->exists($scanImage->image_path)) {
                    $summary['skipped_count']++;
                    $summary['errors'][] = "Scan image {$scanImage->id} skipped because the source file is missing.";
                    continue;
                }

                $speciesFolder = $this->speciesFolderName($scanImage->verifiedSpecies);
                $plantPart = $this->safeFolderName($scanImage->verified_plant_part);
                $filename = $this->buildExportFilename($scanImage);
                $relativeExportPath = "dataset/raw/{$speciesFolder}/{$plantPart}/{$filename}";
                $absoluteExportPath = $this->datasetRootPath() . DIRECTORY_SEPARATOR . 'raw' . DIRECTORY_SEPARATOR . $speciesFolder . DIRECTORY_SEPARATOR . $plantPart . DIRECTORY_SEPARATOR . $filename;

                if (! is_dir(dirname($absoluteExportPath))) {
                    mkdir(dirname($absoluteExportPath), 0755, true);
                }

                copy(Storage::disk('public')->path($scanImage->image_path), $absoluteExportPath);

                $this->appendManifestRow($scanImage, $relativeExportPath);

                $scanImage->update([
                    'dataset_status' => 'exported',
                    'dataset_exported_at' => now(),
                    'dataset_export_path' => str_replace('\\', '/', $relativeExportPath),
                ]);

                $summary['exported_count']++;
            } catch (\Throwable $exception) {
                $summary['skipped_count']++;
                $summary['errors'][] = "Scan image {$scanImage->id} failed: {$exception->getMessage()}";
            }
        }

        return $summary;
    }

    public function speciesFolderName(Species $species): string
    {
        return str_replace(' ', '_', trim($species->scientific_name));
    }

    public function buildExportFilename(ScanImage $scanImage): string
    {
        $species = $scanImage->verifiedSpecies
            ? $this->speciesFolderName($scanImage->verifiedSpecies)
            : 'unknown_species';
        $plantPart = $this->safeFolderName($scanImage->verified_plant_part ?? 'unknown_part');
        $extension = strtolower(pathinfo($scanImage->image_path ?? '', PATHINFO_EXTENSION)) ?: 'jpg';
        $timestamp = now()->format('Ymd_His');

        return "{$species}_{$plantPart}_{$scanImage->id}_{$timestamp}.{$extension}";
    }

    public function appendManifestRow(ScanImage $scanImage, string $exportPath): void
    {
        $manifestPath = $this->manifestPath();
        $this->ensureManifestExists($manifestPath);

        if ($this->manifestHasImage($manifestPath, "scan_image_{$scanImage->id}")) {
            return;
        }

        $scanRecord = $scanImage->scanRecord;
        [$province, $municipality, $barangay] = $this->locationParts($scanRecord?->location_name);

        $handle = fopen($manifestPath, 'ab');

        if ($handle === false) {
            throw new \RuntimeException("Unable to open manifest for writing: {$manifestPath}");
        }

        fputcsv($handle, [
            "scan_image_{$scanImage->id}",
            str_replace('\\', '/', $exportPath),
            $scanImage->verifiedSpecies?->scientific_name ?? '',
            $scanImage->verifiedSpecies?->common_name ?? '',
            $scanImage->verified_plant_part ?? '',
            'SILVAMANG AI uploaded scan image',
            $scanRecord?->user?->name ?? 'unknown',
            'internal academic prototype',
            $province,
            $municipality,
            $barangay,
            $scanRecord?->latitude ?? '',
            $scanRecord?->longitude ?? '',
            $scanRecord?->captured_at?->toDateString() ?? $scanImage->created_at?->toDateString() ?? '',
            $scanImage->image_quality ?? '',
            '',
            'unannotated',
            $scanImage->dataset_notes ?? '',
        ]);

        fclose($handle);
    }

    private function datasetRootPath(): string
    {
        return str_replace('\\', '/', realpath(base_path('..')) ?: base_path('..')) . '/dataset';
    }

    private function manifestPath(): string
    {
        return $this->datasetRootPath() . '/metadata/image_manifest.csv';
    }

    private function safeFolderName(string $value): string
    {
        return Str::of($value)->trim()->replace(' ', '_')->replaceMatches('/[^A-Za-z0-9_\\-]/', '')->toString();
    }

    private function ensureManifestExists(string $manifestPath): void
    {
        if (! is_dir(dirname($manifestPath))) {
            mkdir(dirname($manifestPath), 0755, true);
        }

        if (! file_exists($manifestPath) || filesize($manifestPath) === 0) {
            $handle = fopen($manifestPath, 'wb');
            fputcsv($handle, self::MANIFEST_COLUMNS);
            fclose($handle);
        }
    }

    private function manifestHasImage(string $manifestPath, string $imageId): bool
    {
        if (! file_exists($manifestPath)) {
            return false;
        }

        $handle = fopen($manifestPath, 'rb');

        if ($handle === false) {
            return false;
        }

        while (($row = fgetcsv($handle)) !== false) {
            if (($row[0] ?? null) === $imageId) {
                fclose($handle);
                return true;
            }
        }

        fclose($handle);
        return false;
    }

    private function locationParts(?string $locationName): array
    {
        if (! $locationName) {
            return ['', '', ''];
        }

        $parts = array_map('trim', explode(',', $locationName));

        return [
            $parts[0] ?? '',
            $parts[1] ?? '',
            $parts[2] ?? '',
        ];
    }
}
