<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('scan_images', function (Blueprint $table) {
            $table->foreignId('verified_species_id')->nullable()->after('local_uri')->constrained('species')->nullOnDelete();
            $table->string('verified_plant_part')->nullable()->after('verified_species_id');
            $table->string('dataset_status')->default('pending')->after('verified_plant_part')->index();
            $table->string('image_quality')->nullable()->after('dataset_status')->index();
            $table->foreignId('verified_by')->nullable()->after('image_quality')->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable()->after('verified_by');
            $table->text('rejection_reason')->nullable()->after('verified_at');
            $table->text('dataset_notes')->nullable()->after('rejection_reason');
            $table->timestamp('dataset_exported_at')->nullable()->after('dataset_notes');
            $table->string('dataset_export_path')->nullable()->after('dataset_exported_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('scan_images', function (Blueprint $table) {
            $table->dropForeign(['verified_species_id']);
            $table->dropForeign(['verified_by']);
            $table->dropColumn([
                'verified_species_id',
                'verified_plant_part',
                'dataset_status',
                'image_quality',
                'verified_by',
                'verified_at',
                'rejection_reason',
                'dataset_notes',
                'dataset_exported_at',
                'dataset_export_path',
            ]);
        });
    }
};
