<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ScanRecord extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'record_code',
        'user_id',
        'species_id',
        'top_scientific_name',
        'top_common_name',
        'confidence',
        'capture_mode',
        'identification_status',
        'validation_status',
        'latitude',
        'longitude',
        'accuracy',
        'location_name',
        'address',
        'barangay',
        'manual_barangay',
        'location_lookup_status',
        'height_m',
        'canopy_width_m',
        'notes',
        'offline_reference',
        'captured_at',
        'synced_at',
    ];

    protected $casts = [
        'confidence' => 'decimal:2',
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'accuracy' => 'decimal:2',
        'height_m' => 'decimal:2',
        'canopy_width_m' => 'decimal:2',
        'captured_at' => 'datetime',
        'synced_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function species()
    {
        return $this->belongsTo(Species::class);
    }

    public function images()
    {
        return $this->hasMany(ScanImage::class);
    }

    public function predictions()
    {
        return $this->hasMany(Prediction::class);
    }

    public function measurement()
    {
        return $this->hasOne(Measurement::class);
    }

    public function locationValidation()
    {
        return $this->hasOne(LocationValidation::class);
    }

    public function assistantLogs()
    {
        return $this->hasMany(AssistantLog::class);
    }
}
