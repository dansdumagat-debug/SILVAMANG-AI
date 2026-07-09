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
        Schema::create('ai_models', function (Blueprint $table) {
            $table->id();
            $table->string('model_name')->index();
            $table->string('model_type')->index();
            $table->string('version')->nullable();
            $table->decimal('accuracy', 5, 2)->nullable();
            $table->decimal('precision_score', 5, 2)->nullable();
            $table->decimal('recall_score', 5, 2)->nullable();
            $table->decimal('f1_score', 5, 2)->nullable();
            $table->decimal('top_k_accuracy', 5, 2)->nullable();
            $table->string('status')->default('inactive')->index();
            $table->timestamp('deployed_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_models');
    }
};
