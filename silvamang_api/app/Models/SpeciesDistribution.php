<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SpeciesDistribution extends Model
{
    use HasFactory;

    protected $fillable = [
        'species_id',
        'location_name',
        'province',
        'municipality',
        'barangay',
        'latitude',
        'longitude',
        'radius_km',
        'notes',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'radius_km' => 'decimal:2',
    ];

    public function species()
    {
        return $this->belongsTo(Species::class);
    }
}
