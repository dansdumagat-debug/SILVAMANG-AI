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
        Schema::create('scan_records', function (Blueprint $table) {
            $table->id();
            $table->string('record_code')->unique();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('species_id')->nullable()->constrained('species')->nullOnDelete();
            $table->string('top_scientific_name')->nullable();
            $table->string('top_common_name')->nullable();
            $table->decimal('confidence', 5, 2)->nullable();
            $table->string('capture_mode')->default('guided');
            $table->string('identification_status')->default('pending')->index();
            $table->string('validation_status')->default('pending')->index();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('location_name')->nullable();
            $table->text('address')->nullable();
            $table->text('notes')->nullable();
            $table->string('offline_reference')->nullable();
            $table->timestamp('captured_at')->nullable()->index();
            $table->timestamp('synced_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index('record_code');
            $table->index('user_id');
            $table->index('species_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('scan_records');
    }
};
