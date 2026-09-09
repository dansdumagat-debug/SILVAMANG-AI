<?php

namespace App\Console\Commands;

use App\Services\DatasetExportService;
use Illuminate\Console\Command;

class ExportVerifiedDatasetImages extends Command
{
    protected $signature = 'dataset:export-verified-images';

    protected $description = 'Copy verified scan images into dataset/raw without deleting originals.';

    public function handle(DatasetExportService $exportService): int
    {
        $summary = $exportService->exportVerifiedImages();

        $this->info('Exported: ' . $summary['exported_count']);
        $this->info('Skipped: ' . $summary['skipped_count']);
        $this->info('Errors: ' . count($summary['errors']));

        foreach ($summary['errors'] as $error) {
            $this->warn($error);
        }

        return self::SUCCESS;
    }
}
