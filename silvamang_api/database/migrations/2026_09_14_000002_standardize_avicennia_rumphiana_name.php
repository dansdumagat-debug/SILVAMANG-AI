<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const LEGACY_WITH_PERIOD = 'Avicennia marina var. rumphiana';

    private const LEGACY_CNN_DISPLAY = 'Avicennia marina var rumphiana';

    private const CANONICAL = 'Avicennia rumphiana';

    public function up(): void
    {
        if (Schema::hasTable('species') && ! DB::table('species')->where('scientific_name', self::CANONICAL)->exists()) {
            DB::table('species')
                ->where('scientific_name', self::LEGACY_WITH_PERIOD)
                ->update([
                    'scientific_name' => self::CANONICAL,
                    'conservation_status' => 'Vulnerable',
                    'updated_at' => now(),
                ]);
        }

        $this->replaceHistoricalNames(self::CANONICAL);
    }

    public function down(): void
    {
        if (Schema::hasTable('species') && ! DB::table('species')->where('scientific_name', self::LEGACY_WITH_PERIOD)->exists()) {
            DB::table('species')
                ->where('scientific_name', self::CANONICAL)
                ->update([
                    'scientific_name' => self::LEGACY_WITH_PERIOD,
                    'updated_at' => now(),
                ]);
        }

        $this->replaceHistoricalNames(self::LEGACY_WITH_PERIOD);
    }

    private function replaceHistoricalNames(string $replacement): void
    {
        if (Schema::hasTable('scan_records') && Schema::hasColumn('scan_records', 'top_scientific_name')) {
            DB::table('scan_records')
                ->whereIn('top_scientific_name', [self::LEGACY_WITH_PERIOD, self::LEGACY_CNN_DISPLAY, self::CANONICAL])
                ->update(['top_scientific_name' => $replacement]);
        }

        if (Schema::hasTable('predictions') && Schema::hasColumn('predictions', 'scientific_name')) {
            DB::table('predictions')
                ->whereIn('scientific_name', [self::LEGACY_WITH_PERIOD, self::LEGACY_CNN_DISPLAY, self::CANONICAL])
                ->update(['scientific_name' => $replacement]);
        }

        if (Schema::hasTable('mangrove_knowledge') && Schema::hasColumn('mangrove_knowledge', 'species_name')) {
            DB::table('mangrove_knowledge')
                ->whereIn('species_name', [self::LEGACY_WITH_PERIOD, self::LEGACY_CNN_DISPLAY, self::CANONICAL])
                ->update(['species_name' => $replacement]);
        }
    }
};
