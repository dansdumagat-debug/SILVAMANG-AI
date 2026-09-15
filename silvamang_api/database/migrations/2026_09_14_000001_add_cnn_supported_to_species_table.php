<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('species', 'cnn_supported')) {
            Schema::table('species', function (Blueprint $table) {
                $table->boolean('cnn_supported')->default(false)->index()->after('status');
            });
        }

        DB::table('species')
            ->whereIn('scientific_name', [
                'Avicennia marina',
                'Avicennia marina var. rumphiana',
                'Avicennia rumphiana',
                'Bruguiera gymnorrhiza',
                'Ceriops tagal',
                'Excoecaria agallocha',
                'Rhizophora apiculata',
                'Rhizophora mucronata',
                'Rhizophora stylosa',
                'Sonneratia alba',
                'Xylocarpus granatum',
            ])
            ->update(['cnn_supported' => true]);
    }

    public function down(): void
    {
        if (Schema::hasColumn('species', 'cnn_supported')) {
            Schema::table('species', function (Blueprint $table) {
                $table->dropColumn('cnn_supported');
            });
        }
    }
};
