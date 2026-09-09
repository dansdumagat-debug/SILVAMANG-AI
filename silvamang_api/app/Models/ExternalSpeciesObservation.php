<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ExternalSpeciesObservation extends Model
{
    use HasFactory;

    protected $fillable = [
        'species_id',
        'source',
        'source_observation_id',
        'photo_url',
        'observer',
        'location',
        'latitude',
        'longitude',
        'observed_date',
        'quality_grade',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'observed_date' => 'date',
    ];

    public function species()
    {
        return $this->belongsTo(Species::class);
    }
}
