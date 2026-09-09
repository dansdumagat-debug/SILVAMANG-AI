<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('mangrove_education', function (Blueprint $table) {
            $table->id();
            $table->foreignId('species_id')->constrained('species')->cascadeOnDelete();
            $table->longText('overview')->nullable();
            $table->json('physical_characteristics')->nullable();
            $table->text('leaf_characteristics')->nullable();
            $table->text('root_characteristics')->nullable();
            $table->json('habitat')->nullable();
            $table->json('distribution')->nullable();
            $table->json('ecological_importance')->nullable();
            $table->longText('history')->nullable();
            $table->longText('scientific_study')->nullable();
            $table->json('conservation_information')->nullable();
            $table->json('interesting_facts')->nullable();
            $table->json('references')->nullable();
            $table->string('status')->default('active')->index();
            $table->timestamps();

            $table->unique('species_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mangrove_education');
    }
};
