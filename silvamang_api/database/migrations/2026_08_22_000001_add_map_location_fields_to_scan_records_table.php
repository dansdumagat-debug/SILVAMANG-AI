<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('scan_records', function (Blueprint $table) {
            if (! Schema::hasColumn('scan_records', 'accuracy')) {
                $table->decimal('accuracy', 8, 2)->nullable()->after('longitude');
            }

            if (! Schema::hasColumn('scan_records', 'barangay')) {
                $table->string('barangay')->nullable()->after('address');
            }

            if (! Schema::hasColumn('scan_records', 'manual_barangay')) {
                $table->string('manual_barangay')->nullable()->after('barangay');
            }

            if (! Schema::hasColumn('scan_records', 'location_lookup_status')) {
                $table->string('location_lookup_status')->nullable()->after('manual_barangay');
            }

            if (! Schema::hasColumn('scan_records', 'height_m')) {
                $table->decimal('height_m', 8, 2)->nullable()->after('location_lookup_status');
            }

            if (! Schema::hasColumn('scan_records', 'canopy_width_m')) {
                $table->decimal('canopy_width_m', 8, 2)->nullable()->after('height_m');
            }
        });
    }

    public function down(): void
    {
        Schema::table('scan_records', function (Blueprint $table) {
            foreach ([
                'canopy_width_m',
                'height_m',
                'location_lookup_status',
                'manual_barangay',
                'barangay',
                'accuracy',
            ] as $column) {
                if (Schema::hasColumn('scan_records', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
