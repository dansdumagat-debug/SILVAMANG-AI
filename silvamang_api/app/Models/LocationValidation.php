<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LocationValidation extends Model
{
    use HasFactory;

    protected $fillable = [
        'scan_record_id',
        'species_id',
        'latitude',
        'longitude',
        'result',
        'distance_to_known_distribution_km',
        'message',
        'validated_at',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'distance_to_known_distribution_km' => 'decimal:2',
        'validated_at' => 'datetime',
    ];

    public function scanRecord()
    {
        return $this->belongsTo(ScanRecord::class);
    }

    public function species()
    {
        return $this->belongsTo(Species::class);
    }
}
