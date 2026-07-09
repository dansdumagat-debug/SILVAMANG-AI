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
        Schema::create('scan_images', function (Blueprint $table) {
            $table->id();
            $table->foreignId('scan_record_id')->constrained('scan_records')->cascadeOnDelete();
            $table->string('plant_part')->nullable()->index();
            $table->string('image_path');
            $table->string('original_filename')->nullable();
            $table->string('mime_type')->nullable();
            $table->integer('file_size')->nullable();
            $table->integer('width')->nullable();
            $table->integer('height')->nullable();
            $table->string('local_uri')->nullable();
            $table->timestamps();

            $table->index('scan_record_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('scan_images');
    }
};
