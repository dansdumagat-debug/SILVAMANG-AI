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
        Schema::create('location_validations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('scan_record_id')->constrained('scan_records')->cascadeOnDelete();
            $table->foreignId('species_id')->nullable()->constrained('species')->nullOnDelete();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('result')->default('pending')->index();
            $table->decimal('distance_to_known_distribution_km', 8, 2)->nullable();
            $table->text('message')->nullable();
            $table->timestamp('validated_at')->nullable();
            $table->timestamps();

            $table->index('scan_record_id');
            $table->index('species_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('location_validations');
    }
};
