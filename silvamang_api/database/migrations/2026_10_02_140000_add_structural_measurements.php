<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        foreach (['gbh_cm', 'gbh_m', 'dbh_m', 'basal_area_m2', 'canopy_1_m', 'canopy_2_m'] as $field) {
            if (! Schema::hasColumn('measurements', $field)) {
                Schema::table('measurements', fn (Blueprint $table) => $table->decimal($field, 14, 6)->nullable());
            }
        }
        if (! Schema::hasColumn('scan_records', 'plot_no')) {
            Schema::table('scan_records', fn (Blueprint $table) => $table->string('plot_no', 50)->nullable());
        }
        // Populate only missing conversions for existing, valid measured diameters.
        DB::table('measurements')->where('dbh_cm', '>', 0)->whereNull('dbh_m')
            ->update(['dbh_m' => DB::raw('dbh_cm / 100')]);
        DB::table('measurements')->where('dbh_m', '>', 0)->whereNull('basal_area_m2')
            ->update(['basal_area_m2' => DB::raw('3.141592653589793 * POWER(dbh_m / 2, 2)')]);
    }

    public function down(): void
    {
        // Preserve collected field measurements on rollback.
    }
};
