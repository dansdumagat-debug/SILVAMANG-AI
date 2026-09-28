<?php

namespace Database\Seeders;

use App\Models\Species;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class DeployedModelSpeciesSeeder extends Seeder
{
    public function run(): void
    {
        DB::transaction(function (): void {
            $result = Artisan::call('species:sync-cnn-support', [
                'class-order' => resource_path('ai/class_order.json'),
                '--apply' => true,
            ]);
            if ($result !== 0) {
                throw new RuntimeException(Artisan::output());
            }

            // Remove only the obsolete support claim; preserve botanical notes.
            foreach (Species::query()->get() as $species) {
                $old = 'Knowledge-base species only; not supported by the current 10-class CNN.';
                $notes = (string) $species->identification_notes;
                if (str_contains($notes, $old)) {
                    $species->identification_notes = trim(str_replace($old, '', $notes));
                    $species->save();
                }
            }
        });
    }
}
