<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('scan_records', function (Blueprint $table) {
            $table->text('survey_location')->nullable();
            $table->text('ecological_category')->nullable();
            $table->unsignedInteger('count_mg')->nullable();
            $table->text('substrate')->nullable();
            $table->text('associated_flora')->nullable();
            $table->text('associated_fauna')->nullable();
            $table->text('anthropogenic_activity')->nullable();
            $table->text('impact')->nullable();
            $table->text('other_observations')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('scan_records', function (Blueprint $table) {
            $table->dropColumn(['survey_location', 'ecological_category', 'count_mg', 'substrate', 'associated_flora', 'associated_fauna', 'anthropogenic_activity', 'impact', 'other_observations']);
        });
    }
};
