<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transects', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('transect_code')->unique();
            $table->string('transect_name');
            $table->string('location_name')->nullable();
            $table->text('description')->nullable();
            $table->string('mode', 32)->default('manual_points')->index();
            $table->string('status', 32)->default('completed')->index();
            $table->decimal('start_latitude', 10, 7);
            $table->decimal('start_longitude', 10, 7);
            $table->decimal('end_latitude', 10, 7);
            $table->decimal('end_longitude', 10, 7);
            $table->decimal('total_distance_m', 12, 2)->default(0);
            $table->decimal('bearing_degrees', 7, 2)->nullable();
            $table->decimal('gps_accuracy_m', 8, 2)->nullable();
            $table->json('geometry')->nullable();
            $table->json('pending_observation_references')->nullable();
            $table->string('offline_reference')->nullable()->unique();
            $table->timestamp('recorded_at')->nullable()->index();
            $table->timestamp('synced_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'recorded_at']);
        });

        Schema::create('transect_points', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transect_id')->constrained('transects')->cascadeOnDelete();
            $table->unsignedInteger('sequence_number');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->decimal('accuracy_m', 8, 2)->nullable();
            $table->decimal('altitude_m', 10, 2)->nullable();
            $table->timestamp('recorded_at')->nullable();
            $table->timestamps();

            $table->unique(['transect_id', 'sequence_number']);
        });

        Schema::create('transect_observations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transect_id')->constrained('transects')->cascadeOnDelete();
            $table->foreignId('scan_record_id')->constrained('scan_records')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['transect_id', 'scan_record_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transect_observations');
        Schema::dropIfExists('transect_points');
        Schema::dropIfExists('transects');
    }
};
