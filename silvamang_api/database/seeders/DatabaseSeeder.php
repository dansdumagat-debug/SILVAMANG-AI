<?php

namespace Database\Seeders;

// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            AdminUserSeeder::class,
            SpeciesSeeder::class,
            PanelSpeciesSeeder::class,
            MangroveEducationSeeder::class,
            PanelSpeciesEducationSeeder::class,
            AiModelSeeder::class,
            MangroveKnowledgeSeeder::class,
            PanelMangroveKnowledgeSeeder::class,
            DemoScanRecordSeeder::class,
            TransectDemoSeeder::class,
        ]);
    }
}
