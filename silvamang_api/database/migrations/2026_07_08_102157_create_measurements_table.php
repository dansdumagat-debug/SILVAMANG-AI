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
        Schema::create('measurements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('scan_record_id')->constrained('scan_records')->cascadeOnDelete();
            $table->decimal('height_m', 8, 2)->nullable();
            $table->decimal('canopy_width_m', 8, 2)->nullable();
            $table->decimal('dbh_cm', 8, 2)->nullable();
            $table->string('measurement_method')->default('depth_estimation')->index();
            $table->decimal('confidence', 5, 2)->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('measured_at')->nullable();
            $table->timestamps();

            $table->index('scan_record_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('measurements');
    }
};
