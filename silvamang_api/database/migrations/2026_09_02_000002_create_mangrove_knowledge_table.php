<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('mangrove_knowledge', function (Blueprint $table) {
            $table->id();
            $table->string('category')->index();
            $table->text('question');
            $table->longText('answer');
            $table->string('species_name')->nullable()->index();
            $table->text('keywords')->nullable();
            $table->timestamps();

            $table->index(['category', 'species_name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mangrove_knowledge');
    }
};
