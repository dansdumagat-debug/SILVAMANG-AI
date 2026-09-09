<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('chatbot_logs') || Schema::hasColumn('chatbot_logs', 'user_role')) {
            return;
        }

        Schema::table('chatbot_logs', function (Blueprint $table) {
            $table->string('user_role')->nullable()->after('user_id')->index();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('chatbot_logs') || ! Schema::hasColumn('chatbot_logs', 'user_role')) {
            return;
        }

        Schema::table('chatbot_logs', function (Blueprint $table) {
            $table->dropColumn('user_role');
        });
    }
};
