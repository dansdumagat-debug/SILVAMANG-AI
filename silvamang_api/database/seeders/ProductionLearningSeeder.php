<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;

/** Populate bundled learning content without demo data or overwriting edited lessons. */
class ProductionLearningSeeder extends Seeder
{
    public function run(): void
    {
        foreach (['species', 'mangrove_education', 'mangrove_knowledge'] as $table) {
            if (! Schema::hasTable($table)) {
                throw new RuntimeException("Required table [{$table}] is missing. Check migration status first.");
            }
        }

        DB::transaction(function (): void {
            (new SpeciesSeeder)->run(includeDemoDistributions: false, preserveExisting: true);
            $this->call([PanelSpeciesSeeder::class, DeployedModelSpeciesSeeder::class]);
            (new MangroveEducationSeeder)->run(preserveExisting: true);
            $this->call(PanelSpeciesEducationSeeder::class);
            (new MangroveKnowledgeSeeder)->run(preserveExisting: true);
            $this->call(PanelMangroveKnowledgeSeeder::class);
        });

        $this->command?->info('Learning catalog populated. Existing lessons preserved; no demo records or external references inserted.');
    }
}
