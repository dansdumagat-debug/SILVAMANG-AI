<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('mangrove_knowledge')) {
            return;
        }

        Schema::table('mangrove_knowledge', function (Blueprint $table) {
            if (! Schema::hasColumn('mangrove_knowledge', 'related_species')) {
                $table->text('related_species')->nullable()->after('species_name');
            }

            if (! Schema::hasColumn('mangrove_knowledge', 'status')) {
                $table->string('status')->default('active')->index()->after('keywords');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('mangrove_knowledge')) {
            return;
        }

        Schema::table('mangrove_knowledge', function (Blueprint $table) {
            foreach (['status', 'related_species'] as $column) {
                if (Schema::hasColumn('mangrove_knowledge', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
