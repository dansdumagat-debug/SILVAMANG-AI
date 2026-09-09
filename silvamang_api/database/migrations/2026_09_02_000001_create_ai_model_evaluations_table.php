<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_model_evaluations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('model_id')->constrained('ai_models')->cascadeOnDelete();
            $table->string('metric_name');
            $table->json('metric_value')->nullable();
            $table->date('date');
            $table->timestamps();

            $table->index(['model_id', 'metric_name', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_model_evaluations');
    }
};
