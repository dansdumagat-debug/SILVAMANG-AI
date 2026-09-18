<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transects', function (Blueprint $table) {
            $table->decimal('target_distance_m', 12, 2)->nullable();
            $table->json('contributions')->nullable();
            $table->unsignedInteger('handoff_sequence')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('transects', function (Blueprint $table) {
            $table->dropColumn(['target_distance_m', 'contributions', 'handoff_sequence']);
        });
    }
};
