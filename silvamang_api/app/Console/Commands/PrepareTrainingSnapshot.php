<?php

namespace App\Console\Commands;

use App\Models\ScanImage;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class PrepareTrainingSnapshot extends Command
{
    protected $signature = 'dataset:training-snapshot';

    protected $description = 'Snapshot researcher-approved species photos for the isolated training worker.';

    public function handle(): int
    {
        $root = storage_path('app/retraining-feed');
        if (! is_dir($root.'/images')) {
            mkdir($root.'/images', 0755, true);
        }
        $rows = [];
        $skipped = 0;
        $images = ScanImage::with('verifiedSpecies')
            ->whereIn('dataset_status', ['verified', 'exported'])
            ->whereIn('image_quality', ['good', 'acceptable'])
            ->whereIn('verified_plant_part', ['leaves', 'bark', 'roots', 'flowers'])
            ->whereNotNull('verified_by')->whereNotNull('verified_at')
            ->orderBy('id')->get();
        foreach ($images as $image) {
            if (! $image->verifiedSpecies || ! Storage::disk('public')->exists($image->image_path)) {
                $skipped++;
                continue;
            }
            $source = Storage::disk('public')->path($image->image_path);
            if (@getimagesize($source) === false) {
                $skipped++;
                continue;
            }
            $hash = hash_file('sha256', $source);
            $target = $root.'/images/'.$hash;
            if (! is_file($target)) {
                if (! copy($source, $target.'.pending') || ! rename($target.'.pending', $target)) {
                    throw new \RuntimeException('Could not snapshot training photo.');
                }
            }
            $rows[] = [
                'id' => $image->id,
                'group' => 'scan:'.$image->scan_record_id,
                'species' => str_replace(' ', '_', trim($image->verifiedSpecies->scientific_name)),
                'plant_part' => $image->verified_plant_part,
                'sha256' => $hash,
                'path' => 'images/'.$hash,
                'verified_at' => $image->verified_at->toIso8601String(),
            ];
        }
        $manifest = ['schema' => 1, 'images' => $rows, 'skipped' => $skipped];
        file_put_contents($root.'/manifest.json.pending', json_encode($manifest, JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT));
        rename($root.'/manifest.json.pending', $root.'/manifest.json');
        $this->info('Approved photos: '.count($rows).'; skipped: '.$skipped);

        return self::SUCCESS;
    }
}
