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
        Schema::create('species', function (Blueprint $table) {
            $table->id();
            $table->string('scientific_name')->unique();
            $table->string('common_name')->nullable()->index();
            $table->string('family')->nullable()->index();
            $table->string('genus')->nullable();
            $table->text('description')->nullable();
            $table->text('habitat')->nullable();
            $table->text('distribution_notes')->nullable();
            $table->text('ecological_role')->nullable();
            $table->text('identification_notes')->nullable();
            $table->string('conservation_status')->nullable();
            $table->string('native_status')->nullable();
            $table->decimal('max_height_m', 6, 2)->nullable();
            $table->string('status')->default('active')->index();
            $table->timestamps();
            $table->softDeletes();

            $table->index('scientific_name');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('species');
    }
};
