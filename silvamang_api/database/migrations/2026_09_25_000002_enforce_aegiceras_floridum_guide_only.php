<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const SCIENTIFIC_NAME = 'Aegiceras floridum';

    public function up(): void
    {
        if (
            ! Schema::hasTable('species')
            || ! Schema::hasColumn('species', 'scientific_name')
            || ! Schema::hasColumn('species', 'cnn_supported')
        ) {
            return;
        }

        $updates = ['cnn_supported' => false];
        if (Schema::hasColumn('species', 'updated_at')) {
            $updates['updated_at'] = now();
        }

        DB::table('species')
            ->where('scientific_name', self::SCIENTIFIC_NAME)
            ->update($updates);
    }

    public function down(): void
    {
        // Intentionally keep the species guide-only on rollback. Restoring a
        // true flag could claim support that the deployed CNN does not have.
    }
};
