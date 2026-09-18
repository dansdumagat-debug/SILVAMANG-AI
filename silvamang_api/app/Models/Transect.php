<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Transect extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'transect_code',
        'transect_name',
        'location_name',
        'description',
        'mode',
        'status',
        'start_latitude',
        'start_longitude',
        'end_latitude',
        'end_longitude',
        'total_distance_m',
        'target_distance_m',
        'contributions',
        'handoff_sequence',
        'bearing_degrees',
        'gps_accuracy_m',
        'geometry',
        'pending_observation_references',
        'offline_reference',
        'recorded_at',
        'synced_at',
    ];

    protected $casts = [
        'start_latitude' => 'decimal:7',
        'start_longitude' => 'decimal:7',
        'end_latitude' => 'decimal:7',
        'end_longitude' => 'decimal:7',
        'total_distance_m' => 'decimal:2',
        'target_distance_m' => 'decimal:2',
        'contributions' => 'array',
        'handoff_sequence' => 'integer',
        'bearing_degrees' => 'decimal:2',
        'gps_accuracy_m' => 'decimal:2',
        'geometry' => 'array',
        'pending_observation_references' => 'array',
        'recorded_at' => 'datetime',
        'synced_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function points()
    {
        return $this->hasMany(TransectPoint::class)->orderBy('sequence_number');
    }

    public function observations()
    {
        return $this->belongsToMany(ScanRecord::class, 'transect_observations')
            ->withTimestamps();
    }
}
