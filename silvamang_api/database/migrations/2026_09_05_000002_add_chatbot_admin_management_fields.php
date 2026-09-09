<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('mangrove_knowledge')) {
            Schema::table('mangrove_knowledge', function (Blueprint $table) {
                if (! Schema::hasColumn('mangrove_knowledge', 'reference_source')) {
                    $afterColumn = Schema::hasColumn('mangrove_knowledge', 'related_species')
                        ? 'related_species'
                        : 'species_name';

                    $table->string('reference_source', 2000)->nullable()->after($afterColumn);
                }
            });
        }

        if (Schema::hasTable('chatbot_logs')) {
            Schema::table('chatbot_logs', function (Blueprint $table) {
                if (! Schema::hasColumn('chatbot_logs', 'response_source')) {
                    $table->string('response_source')->nullable()->after('source')->index();
                }

                if (! Schema::hasColumn('chatbot_logs', 'user_role')) {
                    $table->string('user_role')->nullable()->after('user_id')->index();
                }
            });
        }

        if (! Schema::hasTable('unanswered_questions')) {
            Schema::create('unanswered_questions', function (Blueprint $table) {
                $table->id();
                $table->text('question');
                $table->unsignedInteger('frequency')->default(1);
                $table->string('status')->default('open')->index();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('unanswered_questions');

        if (Schema::hasTable('chatbot_logs') && Schema::hasColumn('chatbot_logs', 'response_source')) {
            Schema::table('chatbot_logs', function (Blueprint $table) {
                $table->dropColumn('response_source');
            });
        }

        if (Schema::hasTable('chatbot_logs') && Schema::hasColumn('chatbot_logs', 'user_role')) {
            Schema::table('chatbot_logs', function (Blueprint $table) {
                $table->dropColumn('user_role');
            });
        }

        if (Schema::hasTable('mangrove_knowledge') && Schema::hasColumn('mangrove_knowledge', 'reference_source')) {
            Schema::table('mangrove_knowledge', function (Blueprint $table) {
                $table->dropColumn('reference_source');
            });
        }
    }
};
