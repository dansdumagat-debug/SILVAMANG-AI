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
        Schema::create('alerts', function (Blueprint $table) {
            $table->id();
            $table->string('alert_type')->index();
            $table->string('severity')->default('low')->index();
            $table->string('title');
            $table->text('message')->nullable();
            $table->foreignId('related_scan_record_id')->nullable()->constrained('scan_records')->nullOnDelete();
            $table->string('status')->default('open')->index();
            $table->timestamps();

            $table->index('related_scan_record_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('alerts');
    }
};
