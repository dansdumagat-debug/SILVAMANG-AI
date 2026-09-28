<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const SCIENTIFIC_NAME = 'Acanthus volubilis';

    /**
     * Remove the retired species from active catalogs without destroying
     * historical scan and prediction relationships.
     */
    public function up(): void
    {
        DB::transaction(function (): void {
            $speciesIds = $this->speciesIds();

            if ($speciesIds->isNotEmpty()) {
                $this->deactivateEducation($speciesIds->all());

                $updates = [];

                if (Schema::hasColumn('species', 'status')) {
                    $updates['status'] = 'inactive';
                }

                if (Schema::hasColumn('species', 'cnn_supported')) {
                    $updates['cnn_supported'] = false;
                }

                if (Schema::hasColumn('species', 'deleted_at')) {
                    $updates['deleted_at'] = now();
                }

                if (Schema::hasColumn('species', 'updated_at')) {
                    $updates['updated_at'] = now();
                }

                if ($updates !== []) {
                    DB::table('species')
                        ->whereIn('id', $speciesIds)
                        ->update($updates);
                }
            }

            $this->setKnowledgeStatus('inactive');
        });
    }

    public function down(): void
    {
        DB::transaction(function (): void {
            $speciesIds = $this->speciesIds();

            if ($speciesIds->isNotEmpty()) {
                $updates = [];

                if (Schema::hasColumn('species', 'status')) {
                    $updates['status'] = 'active';
                }

                if (Schema::hasColumn('species', 'cnn_supported')) {
                    $updates['cnn_supported'] = false;
                }

                if (Schema::hasColumn('species', 'deleted_at')) {
                    $updates['deleted_at'] = null;
                }

                if (Schema::hasColumn('species', 'updated_at')) {
                    $updates['updated_at'] = now();
                }

                if ($updates !== []) {
                    DB::table('species')
                        ->whereIn('id', $speciesIds)
                        ->update($updates);
                }

                $this->setEducationStatus($speciesIds->all(), 'active');
            }

            $this->setKnowledgeStatus('active');
        });
    }

    private function speciesIds()
    {
        if (! Schema::hasTable('species')) {
            return collect();
        }

        return DB::table('species')
            ->where('scientific_name', self::SCIENTIFIC_NAME)
            ->pluck('id');
    }

    /** @param array<int, int|string> $speciesIds */
    private function deactivateEducation(array $speciesIds): void
    {
        $this->setEducationStatus($speciesIds, 'inactive');
    }

    /** @param array<int, int|string> $speciesIds */
    private function setEducationStatus(array $speciesIds, string $status): void
    {
        if (
            $speciesIds === []
            || ! Schema::hasTable('mangrove_education')
            || ! Schema::hasColumn('mangrove_education', 'status')
        ) {
            return;
        }

        $updates = ['status' => $status];
        if (Schema::hasColumn('mangrove_education', 'updated_at')) {
            $updates['updated_at'] = now();
        }

        DB::table('mangrove_education')
            ->whereIn('species_id', $speciesIds)
            ->update($updates);
    }

    private function setKnowledgeStatus(string $status): void
    {
        if (
            ! Schema::hasTable('mangrove_knowledge')
            || ! Schema::hasColumn('mangrove_knowledge', 'species_name')
            || ! Schema::hasColumn('mangrove_knowledge', 'status')
        ) {
            return;
        }

        $updates = ['status' => $status];
        if (Schema::hasColumn('mangrove_knowledge', 'updated_at')) {
            $updates['updated_at'] = now();
        }

        DB::table('mangrove_knowledge')
            ->where('species_name', self::SCIENTIFIC_NAME)
            ->update($updates);
    }
};
