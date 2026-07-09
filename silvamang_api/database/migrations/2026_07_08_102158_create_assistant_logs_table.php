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
        Schema::create('assistant_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('scan_record_id')->nullable()->constrained('scan_records')->nullOnDelete();
            $table->text('question')->nullable();
            $table->text('response')->nullable();
            $table->string('intent')->nullable()->index();
            $table->string('source')->nullable();
            $table->timestamps();

            $table->index('user_id');
            $table->index('scan_record_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('assistant_logs');
    }
};
