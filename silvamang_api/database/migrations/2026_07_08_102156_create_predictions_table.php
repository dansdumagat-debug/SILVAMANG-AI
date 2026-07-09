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
        Schema::create('predictions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('scan_record_id')->constrained('scan_records')->cascadeOnDelete();
            $table->foreignId('species_id')->nullable()->constrained('species')->nullOnDelete();
            $table->unsignedInteger('rank')->index();
            $table->string('scientific_name');
            $table->string('common_name')->nullable();
            $table->decimal('confidence', 5, 2)->index();
            $table->string('model_name')->nullable();
            $table->string('model_version')->nullable();
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
        Schema::dropIfExists('predictions');
    }
};
