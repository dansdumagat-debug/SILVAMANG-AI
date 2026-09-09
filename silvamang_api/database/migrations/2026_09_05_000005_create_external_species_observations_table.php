<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (Schema::hasTable('external_species_observations')) {
            $this->addMissingIndexes();

            return;
        }

        Schema::create('external_species_observations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('species_id')->nullable()->constrained('species')->nullOnDelete();
            $table->string('source')->default('inaturalist')->index('eso_source_index');
            $table->string('source_observation_id')->index();
            $table->string('photo_url')->nullable();
            $table->string('observer')->nullable();
            $table->string('location')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->date('observed_date')->nullable();
            $table->string('quality_grade')->nullable()->index('eso_quality_grade_index');
            $table->timestamps();

            $table->unique(['source', 'source_observation_id'], 'eso_source_observation_unique');
            $table->index(['species_id', 'source'], 'eso_species_source_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('external_species_observations');
    }

    private function addMissingIndexes(): void
    {
        if (! $this->indexExists('eso_source_observation_unique')) {
            Schema::table('external_species_observations', function (Blueprint $table) {
                $table->unique(['source', 'source_observation_id'], 'eso_source_observation_unique');
            });
        }

        if (! $this->indexExists('eso_source_index')) {
            Schema::table('external_species_observations', function (Blueprint $table) {
                $table->index('source', 'eso_source_index');
            });
        }

        if (! $this->indexExists('eso_quality_grade_index')) {
            Schema::table('external_species_observations', function (Blueprint $table) {
                $table->index('quality_grade', 'eso_quality_grade_index');
            });
        }

        if (! $this->indexExists('eso_species_source_index')) {
            Schema::table('external_species_observations', function (Blueprint $table) {
                $table->index(['species_id', 'source'], 'eso_species_source_index');
            });
        }
    }

    private function indexExists(string $indexName): bool
    {
        $indexes = DB::select('SHOW INDEX FROM external_species_observations');

        foreach ($indexes as $index) {
            if (($index->Key_name ?? null) === $indexName) {
                return true;
            }
        }

        return false;
    }
};
